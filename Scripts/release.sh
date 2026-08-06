#!/usr/bin/env bash
# release.sh — build → codesign → notarize → DMG, all in one shot.
#
# Designed to run inside CI (privacykey/gh-workflows'
# macos-sparkle-release.yml, called from .github/workflows/release.yml)
# but works locally too if you've imported the Developer ID cert into
# the default keychain and stashed the notary credentials in your
# environment. Follows that workflow's release-script env contract.
#
# Outputs:
#   dist/BananaBlitz-<version>.dmg             — signed + notarized + stapled
#   symbols/BananaBlitz-<version>.app.dSYM.zip — for crash symbolication
#
# Required environment (App Store Connect API key for notarytool):
#   APPLE_API_KEY_PATH          Path to the ASC .p8 key file.
#   APPLE_API_KEY_ID            10-char Key ID.
#   APPLE_API_ISSUER            Issuer UUID.
#
# Optional:
#   APPLE_SIGNING_IDENTITY      Developer ID common name (defaults to
#                               the first matching cert in the
#                               keychain; DEVELOPER_ID still works as
#                               a legacy alias).
#   KEYCHAIN_PATH               Keychain for the direct codesign call
#                               (CI's ephemeral keychain; omit locally
#                               to use the default search list).
#   SCHEME                      xcodebuild scheme (default: BananaBlitz).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SCHEME="${SCHEME:-BananaBlitz}"
CONFIG="Release"

# Fail fast if the notarization credentials are missing.
for var in APPLE_API_KEY_PATH APPLE_API_KEY_ID APPLE_API_ISSUER; do
  if [[ -z "${!var:-}" ]]; then
    echo "error: $var is unset — notarytool needs the App Store Connect API key" >&2
    echo "       (key file path, 10-char Key ID, and Issuer UUID)" >&2
    exit 2
  fi
done
NOTARY_ARGS=(
  --key     "$APPLE_API_KEY_PATH"
  --key-id  "$APPLE_API_KEY_ID"
  --issuer  "$APPLE_API_ISSUER"
)
ARCHIVE_PATH="$REPO_ROOT/dist/${SCHEME}.xcarchive"
EXPORT_PATH="$REPO_ROOT/dist/export"
DIST_DIR="$REPO_ROOT/dist"
mkdir -p "$DIST_DIR"

# ── 1. Resolve the version from project.yml ────────────────────────
# MARKETING_VERSION in project.yml is the canonical version. The
# Info.plist references it via $(MARKETING_VERSION) substitution, so
# reading the plist directly returns the literal string. The
# variable's actual value lives here.
VERSION="$(grep -E '^[[:space:]]*MARKETING_VERSION:' "$REPO_ROOT/project.yml" \
  | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
if [[ -z "$VERSION" ]]; then
  echo "error: could not read MARKETING_VERSION from project.yml" >&2
  exit 2
fi
echo "Building BananaBlitz v$VERSION"

# Make sure xcodegen has been run before we try to archive.
if [[ ! -d "$REPO_ROOT/BananaBlitz.xcodeproj" ]]; then
  echo "BananaBlitz.xcodeproj missing — running xcodegen"
  xcodegen generate
fi

# ── 2. Resolve the signing identity ────────────────────────────────
# CI provides APPLE_SIGNING_IDENTITY; locally we fall back to probing
# the keychain (DEVELOPER_ID kept as a legacy alias).
DEVELOPER_ID="${APPLE_SIGNING_IDENTITY:-${DEVELOPER_ID:-$(security find-identity -v -p codesigning \
  | awk -F'"' '/Developer ID Application/ {print $2; exit}')}}"
if [[ -z "$DEVELOPER_ID" ]]; then
  echo "error: no Developer ID Application identity found in keychain" >&2
  exit 2
fi
echo "Signing as: $DEVELOPER_ID"

# ── 3. Archive the app target ──────────────────────────────────────
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
  CODE_SIGN_STYLE=Manual \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS='--timestamp --options=runtime' \
  archive

# ── 4. Export the .app from the archive ────────────────────────────
EXPORT_OPTIONS_PLIST="$REPO_ROOT/dist/ExportOptions.plist"
cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>            <string>developer-id</string>
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

# ── 4b. Stage the dSYM for crash symbolication ─────────────────────
# Kept in symbols/ (not dist/) so Sparkle's generate_appcast doesn't
# treat it as another release archive; CI moves it into dist/ after
# the appcast is generated.
DSYM_SRC="$ARCHIVE_PATH/dSYMs/${SCHEME}.app.dSYM"
if [[ -d "$DSYM_SRC" ]]; then
  SYMBOLS_DIR="$REPO_ROOT/symbols"
  mkdir -p "$SYMBOLS_DIR"
  DSYM_ZIP="$SYMBOLS_DIR/${SCHEME}-${VERSION}.app.dSYM.zip"
  rm -f "$DSYM_ZIP"
  ditto -c -k --keepParent "$DSYM_SRC" "$DSYM_ZIP"
  echo "dSYM staged: $DSYM_ZIP"
else
  echo "warning: no dSYM at $DSYM_SRC — crashes won't be symbolicatable" >&2
fi

# ── 5. Notarize the .app ───────────────────────────────────────────
ZIP_PATH="$DIST_DIR/${SCHEME}-notarize.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
  "${NOTARY_ARGS[@]}" \
  --wait

# Staple so Gatekeeper can verify offline.
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

# Drop the notarization zip: CI's generate_appcast scans everything in
# dist/, and a second archive containing the same app version would
# collide with the DMG.
rm -f "$ZIP_PATH"

# ── 6. Build the DMG ───────────────────────────────────────────────
DMG_PATH="$DIST_DIR/BananaBlitz-$VERSION.dmg"
rm -f "$DMG_PATH"
DMG_STAGING="$(mktemp -d)"
trap 'rm -rf "$DMG_STAGING"' EXIT
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "BananaBlitz" \
  -srcfolder "$DMG_STAGING" \
  -ov -format UDZO \
  "$DMG_PATH"

# Sign + staple the DMG itself so the download isn't quarantined on
# first open. Pin codesign to the CI keychain when one is provided so
# it never falls through to an interactive unlock prompt.
if [[ -n "${KEYCHAIN_PATH:-}" ]]; then
  codesign --force --keychain "$KEYCHAIN_PATH" --sign "$DEVELOPER_ID" "$DMG_PATH"
else
  codesign --force --sign "$DEVELOPER_ID" "$DMG_PATH"
fi
xcrun notarytool submit "$DMG_PATH" \
  "${NOTARY_ARGS[@]}" \
  --wait
xcrun stapler staple "$DMG_PATH"

echo
echo "──────────────────────────────────────────────"
echo "DMG ready: $DMG_PATH"
echo "──────────────────────────────────────────────"
