#!/usr/bin/env bash
# release.sh — build → codesign → notarize → DMG, all in one shot.
#
# Driven in CI by the shared release pipeline (privacykey/gh-workflows'
# macos-sparkle-release.yml, called from .github/workflows/release.yml)
# and runnable locally through `just release-local` once the Developer ID
# certificate is in the keychain and ~/.config/apple/signing.env names
# the notarization credentials. Follows the shared release-script contract:
#
#   reads:  APPLE_SIGNING_IDENTITY  APPLE_API_KEY_PATH  APPLE_API_KEY_ID
#           APPLE_API_ISSUER        KEYCHAIN_PATH       SCHEME
#   writes: dist/BananaBlitz-<version>.dmg              signed + notarized + stapled
#           symbols/BananaBlitz-<version>.app.dSYM.zip  for crash symbolication
#
# Notarization credentials (loaded from ~/.config/apple/signing.env):
#   APPLE_NOTARY_PROFILE        Preferred locally: saved notarytool Keychain profile.
#   or APPLE_API_KEY_PATH/APPLE_API_KEY_ID/APPLE_API_ISSUER (what CI provides)
#   or APPLE_NOTARY_USER/APPLE_NOTARY_PASSWORD/APPLE_TEAM_ID.
# Xcode account login handles signing/provisioning; notarization is separate.
# See docs/apple-signing.md.
#
# Optional:
#   APPLE_DEVELOPER_ID_IDENTITY Pin the Developer ID Application identity
#                               when several are available. CI supplies
#                               APPLE_SIGNING_IDENTITY instead; DEVELOPER_ID
#                               remains a legacy alias. With none of them
#                               set, the first matching keychain identity
#                               is used.
#   KEYCHAIN_PATH               Keychain holding the Developer ID identity.
#                               Set by CI (the shared workflow's ephemeral
#                               keychain); omit locally and codesign falls
#                               back to the default keychain search list.
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
# Single staging area for transient build artefacts (the notarize-zip
# upload payload, the DMG staging tree). Nothing here may end up in
# dist/: Sparkle's generate_appcast scans dist/ for release archives, and
# a second archive carrying the same bundle version breaks the appcast
# step. Removed unconditionally on exit, success or failure.
TMP_DIR="$(mktemp -d -t bananablitz-release)"
trap 'rm -rf "$TMP_DIR"; rm -f "$PROJECT_SOURCE_RECORD"' EXIT
project_command source-capture "$PROJECT_SOURCE_RECORD"

cd "$REPO_ROOT"

SCHEME="${SCHEME:-BananaBlitz}"
CONFIG="Release"
DIST_DIR="$REPO_ROOT/dist"
ARCHIVE_PATH="$DIST_DIR/${SCHEME}.xcarchive"
EXPORT_PATH="$DIST_DIR/export"
SYMBOLS_DIR="$REPO_ROOT/symbols"
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
# CI sets APPLE_SIGNING_IDENTITY explicitly so the release is signed with
# the exact certificate its secrets describe. Locally,
# APPLE_DEVELOPER_ID_IDENTITY pins a Developer ID when several are
# present; it wins over APPLE_SIGNING_IDENTITY so an Apple Development
# choice made for archives never leaks into a direct release. With
# neither set, the keychain is probed for the first Developer ID.
DEVELOPER_ID="${APPLE_DEVELOPER_ID_IDENTITY:-${APPLE_SIGNING_IDENTITY:-${DEVELOPER_ID:-$(security find-identity -v -p codesigning \
  | awk -F'"' '/Developer ID Application/ {print $2; exit}')}}}"
if [[ -z "$DEVELOPER_ID" ]]; then
  echo "error: no Developer ID Application identity available" >&2
  echo "       Set APPLE_DEVELOPER_ID_IDENTITY (CI: APPLE_SIGNING_IDENTITY), or import a" >&2
  echo "       Developer ID Application certificate into your login keychain." >&2
  exit 2
fi
if [[ "$DEVELOPER_ID" != "Developer ID Application:"* ]]; then
  echo "error: direct releases must be signed with a Developer ID Application identity" >&2
  echo "       got: $DEVELOPER_ID" >&2
  exit 2
fi
echo "Signing as: $DEVELOPER_ID"

# Apple fixes the identity format as "Developer ID Application: <Name>
# (TEAMID)". That team is passed as DEVELOPMENT_TEAM so xcodebuild and
# the certificate always agree, and must match any configured team.
certificate_team="$(printf '%s' "$DEVELOPER_ID" | sed -nE 's/.*\(([A-Z0-9]{10})\)$/\1/p')"
if [[ -z "$certificate_team" ]]; then
  echo "error: could not read a 10-character team ID from the identity: $DEVELOPER_ID" >&2
  exit 2
fi
TEAM_ID="${TEAM_ID_OVERRIDE:-${APPLE_TEAM_ID:-$certificate_team}}"
if [[ "$TEAM_ID" != "$certificate_team" ]]; then
  echo "error: configured Apple team $TEAM_ID does not match the Developer ID Application certificate ($certificate_team)" >&2
  exit 2
fi
echo "Using DEVELOPMENT_TEAM: $TEAM_ID"

# Resolve notarization independently from Xcode provisioning before archiving.
notary_arguments_file="$TMP_DIR/notary-args"
if ! python3 "$REPO_ROOT/Scripts/apple_signing.py" --notary-args > "$notary_arguments_file"; then
  exit 2
fi
notary_auth=()
while IFS= read -r -d '' argument; do notary_auth+=("$argument"); done < "$notary_arguments_file"

# ── 3. Archive the app target ──────────────────────────────────────
# Settings given on the command line win over project.pbxproj: manual
# signing (no automatic-provisioning round-trip from CI), the exact
# identity, the certificate's team, and the hardened runtime that
# notarization requires. The scheme's pre-action captures the UTC build
# identity; `archive` selects the release channel for it.
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
EXPORT_OPTIONS_PLIST="$DIST_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
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
PLIST
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
# The upload zip exists only to ship the .app to Apple's notary service;
# it is staged outside dist/ so generate_appcast never sees it.
ZIP_PATH="$TMP_DIR/${SCHEME}-notarize.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

# `--wait` blocks until Apple returns Accepted or Invalid; Invalid exits
# non-zero and `set -e` stops the release.
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
DMG_STAGING="$TMP_DIR/dmg-staging"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "BananaBlitz" \
  -srcfolder "$DMG_STAGING" \
  -ov -format UDZO \
  "$DMG_PATH"

# Sign + staple the DMG itself so the download isn't quarantined on
# first open. In CI, pin codesign to the ephemeral keychain the
# certificate was imported into (KEYCHAIN_PATH, from the shared
# workflow) so it never falls through to an interactive unlock prompt;
# locally, fall back to the default keychain search list.
if [[ -n "${KEYCHAIN_PATH:-}" ]]; then
  codesign --force --sign "$DEVELOPER_ID" --keychain "$KEYCHAIN_PATH" "$DMG_PATH"
else
  codesign --force --sign "$DEVELOPER_ID" "$DMG_PATH"
fi
xcrun notarytool submit "$DMG_PATH" \
  "${notary_auth[@]}" \
  --wait
xcrun stapler staple "$DMG_PATH"
project_command record-package "$DMG_PATH" --from-artifact "$APP_PATH" --channel release

# ── 7. Package the dSYM for crash symbolication ────────────────────
# xcodebuild leaves the .dSYM inside the archive. Zip it into symbols/,
# not dist/, because generate_appcast would treat another zip in dist/
# as a release archive. The shared workflow moves it into dist/ once the
# appcast exists and attaches it to the GitHub Release.
DSYM_SRC="$ARCHIVE_PATH/dSYMs/${SCHEME}.app.dSYM"
DSYM_ZIP="$SYMBOLS_DIR/BananaBlitz-$VERSION.app.dSYM.zip"
if [[ -d "$DSYM_SRC" ]]; then
  mkdir -p "$SYMBOLS_DIR"
  rm -f "$DSYM_ZIP"
  ditto -c -k --keepParent "$DSYM_SRC" "$DSYM_ZIP"
  echo "dSYM packaged: $DSYM_ZIP"
else
  echo "warning: no dSYM at $DSYM_SRC — field crashes for this release won't be symbolicatable" >&2
fi

echo
echo "──────────────────────────────────────────────"
echo "DMG ready: $DMG_PATH"
[[ -f "$DSYM_ZIP" ]] && echo "dSYM ready: $DSYM_ZIP"
echo "──────────────────────────────────────────────"
