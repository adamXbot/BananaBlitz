#!/usr/bin/env bash
# release.sh — build → codesign → notarize → DMG, all in one shot.
#
# Designed to run inside CI (.github/workflows/release.yml) but works
# locally too if you've imported the Developer ID cert into the
# default keychain and stashed the notary credentials in your
# environment.
#
# Outputs:
#   dist/BananaBlitz-<version>.dmg — signed + notarized + stapled
#
# Notarization credentials (loaded from ~/.config/apple/signing.env):
#   APPLE_NOTARY_PROFILE        Preferred: saved notarytool Keychain profile.
#   or APPLE_API_KEY_PATH/APPLE_API_KEY_ID/APPLE_API_ISSUER
#   or APPLE_NOTARY_USER/APPLE_NOTARY_PASSWORD/APPLE_TEAM_ID.
# Xcode account login handles signing/provisioning; notarization is separate.
# See docs/apple-signing.md.
#
# Optional:
#   DEVELOPER_ID                Override the Developer ID common name
#                               (defaults to the first matching cert
#                               in the keychain).
#   SCHEME                      xcodebuild scheme (default: BananaBlitz).

set -euo pipefail

# Load the shared settings once, including when invoked outside just.
if [[ "${APPLE_SIGNING_LOADED:-}" != "1" ]]; then
  exec python3 "$(dirname "$0")/apple_signing.py" --exec bash "$0" "$@"
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Verify publication before signing/notarization; capture source before compilation.
project_command() {
  python3 "$REPO_ROOT/.project/projectctl.py" --config "$REPO_ROOT/.project/commands.json" "$@"
}
project_command source-check --channel release
PROJECT_SOURCE_RECORD="$(mktemp -t project-release-source)"
project_command source-capture "$PROJECT_SOURCE_RECORD"
trap 'rm -f "$PROJECT_SOURCE_RECORD"' EXIT

cd "$REPO_ROOT"

SCHEME="${SCHEME:-BananaBlitz}"
CONFIG="Release"
ARCHIVE_PATH="$REPO_ROOT/dist/${SCHEME}.xcarchive"
EXPORT_PATH="$REPO_ROOT/dist/export"
DIST_DIR="$REPO_ROOT/dist"
mkdir -p "$DIST_DIR"

# ── 1. Read the canonical marketing version ────────────────────────
# MARKETING_VERSION in Config/Shared.xcconfig is the canonical version. The
# Info.plist references it via $(MARKETING_VERSION) substitution, so
# reading the plist directly returns the literal string. The
# variable's actual value lives here.
VERSION="$(sed -nE 's/^MARKETING_VERSION[[:space:]]*=[[:space:]]*([0-9.]+).*/\1/p' "$REPO_ROOT/Config/Shared.xcconfig" | head -1)"
if [[ -z "$VERSION" ]]; then
  echo "error: could not read MARKETING_VERSION from Config/Shared.xcconfig" >&2
  exit 2
fi
echo "Building BananaBlitz v$VERSION"

# Make sure xcodegen has been run before we try to archive.
if [[ ! -d "$REPO_ROOT/BananaBlitz.xcodeproj" ]]; then
  echo "BananaBlitz.xcodeproj missing — running xcodegen"
  xcodegen generate
fi

# ── 2. Resolve the signing identity ────────────────────────────────
DEVELOPER_ID="${APPLE_DEVELOPER_ID_IDENTITY:-${DEVELOPER_ID:-$(security find-identity -v -p codesigning \
  | awk -F'"' '/Developer ID Application/ {print $2; exit}')}}"
if [[ -z "$DEVELOPER_ID" ]]; then
  echo "error: no Developer ID Application identity found in keychain" >&2
  exit 2
fi
echo "Signing as: $DEVELOPER_ID"

certificate_team="$(printf '%s' "$DEVELOPER_ID" | sed -nE 's/.*\(([A-Z0-9]{10})\)$/\1/p')"
TEAM_ID="${APPLE_TEAM_ID:-$certificate_team}"
if [[ -z "$certificate_team" || "$TEAM_ID" != "$certificate_team" ]]; then
  echo "error: configured Apple team does not match a Developer ID Application certificate" >&2
  exit 2
fi
# Resolve notarization independently from Xcode provisioning before archiving.
notary_arguments_file="$(mktemp)"
if ! python3 "$REPO_ROOT/Scripts/apple_signing.py" --notary-args > "$notary_arguments_file"; then
  rm -f "$notary_arguments_file"
  exit 2
fi
notary_auth=()
while IFS= read -r -d '' argument; do notary_auth+=("$argument"); done < "$notary_arguments_file"
rm -f "$notary_arguments_file"

# ── 3. Archive the app target ──────────────────────────────────────
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS='--timestamp --options=runtime' \
  archive

project_command record-artifact "$ARCHIVE_PATH" --source-record "$PROJECT_SOURCE_RECORD"

# ── 4. Export the .app from the archive ────────────────────────────
EXPORT_OPTIONS_PLIST="$REPO_ROOT/dist/ExportOptions.plist"
cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>            <string>developer-id</string>
  <key>teamID</key>            <string>${TEAM_ID}</string>
  <key>signingStyle</key>      <string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath  "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

APP_PATH="$EXPORT_PATH/${SCHEME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: exported .app missing at $APP_PATH" >&2
  exit 2
fi

# ── 5. Notarize the .app ───────────────────────────────────────────
ZIP_PATH="$DIST_DIR/${SCHEME}-notarize.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
  "${notary_auth[@]}" \
  --wait

# Staple so Gatekeeper can verify offline.
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
project_command record-artifact "$APP_PATH" --source-record "$PROJECT_SOURCE_RECORD"
project_command artifact-verify "$APP_PATH" --channel release


# ── 6. Build the DMG ───────────────────────────────────────────────
DMG_PATH="$DIST_DIR/BananaBlitz-$VERSION.dmg"
rm -f "$DMG_PATH"
DMG_STAGING="$(mktemp -d)"
trap 'rm -rf "$DMG_STAGING"; rm -f "$PROJECT_SOURCE_RECORD"' EXIT
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "BananaBlitz" \
  -srcfolder "$DMG_STAGING" \
  -ov -format UDZO \
  "$DMG_PATH"

# Sign + staple the DMG itself so the download isn't quarantined on
# first open.
codesign --force --sign "$DEVELOPER_ID" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" \
  "${notary_auth[@]}" \
  --wait
xcrun stapler staple "$DMG_PATH"
project_command record-package "$DMG_PATH" --from-artifact "$APP_PATH" --channel release


echo
echo "──────────────────────────────────────────────"
echo "DMG ready: $DMG_PATH"
echo "──────────────────────────────────────────────"
