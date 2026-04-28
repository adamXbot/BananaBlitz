# BananaBlitz 🍌

BananaBlitz is a lightweight, stealthy native macOS utility that helps you reclaim your privacy by periodically cleaning up deep system telemetry databases, Siri intelligence metrics, and tracking logs within your `~/Library` folder.

Instead of disabling System Integrity Protection (SIP), BananaBlitz uses macOS native constructs (the user-immutable flag, equivalent to `chflags uchg`) to selectively neuter unwanted directories and stop Apple daemons from logging metrics, without risking breaking your OS.

> [!CAUTION]
> **Use at your own risk.** BananaBlitz modifies system-generated files and directories within your `~/Library` folder. The "Lock with Immutable File" strategy *is* destructive — it deletes the original directory and replaces it with a locked empty file — but the operation is reversible via the in-app "Save Recovery Script…" button (Settings → Preferences → Data) or the bundled `unbrick.sh`. The developers are not responsible for any data loss, system instability, or unexpected behavior resulting from the use of this utility. Always ensure you have a recent backup of your data.

##
via brew `brew install adamxbot/tap/bananablitz`
Or `brew tap adamxbot/tap` and then `brew install bananablitz`.

Or via the [latest release](https://github.com/adamXbot/BananaBlitz/releases/latest)

Note, you will need to remove app from quarantine as it isn't notarised. This can be done with
`xattr -cr /Applications/BananaBlitz.app`

## Features
- **3 Privacy Levels:** Select from Basic (caches), Strong (Biome intelligence), and Paranoid (screentime, Siri profiling).
- **Stealth Background Execution:** Set schedules to clean hourly, daily, or on-demand.
- **Smart Directory Locking:** Replace directories with immutable empty files to block intrusive re-creations natively using `uchg`.
- **Menu Bar Ready:** Fully built for your menu bar, cleanly getting out of the way.

## Keyboard Shortcut
You can quickly open BananaBlitz from anywhere by pressing `Command` + `Control` + `b`. This feature is disabled by default. To enable it, open the app, go to Settings -> Preferences, and toggle "Menu Bar Global Shortcut (⌘⌃B)".

## Build Requirements
- macOS 14.0+
- Xcode 15+

## How to Compile
BananaBlitz uses XcodeGen to manage its project generation to avoid messy git conflicts on `.pbxproj`.

1. Ensure you have `xcodegen` installed (`brew install xcodegen`).
2. Run `xcodegen generate` in the root folder.
3. Open `BananaBlitz.xcodeproj` and build!

## Permissions
Due to the system-level protections imposed by macOS over the `~/Library/` directory for apps, BananaBlitz requires **Full Disk Access** and is built without App Sandbox enabled. The onboarding wizard will guide you to enable this!

## Reverting
If you need to revert the changes made by BananaBlitz, run the bundled recovery script:

```bash
./Scripts/unbrick.sh
```

This will remove the immutable flag from the locked directories and files, and recreate them as normal directories and files.

This may happen if you select the paranoid option.

The script bundled in this repo is **auto-generated** from the canonical `PrivacyTarget.allTargets` registry. To regenerate it for your local target list, open the app and use **Settings → Preferences → Data → Save Recovery Script…**, or call `UnbrickScriptGenerator.write(to:)` directly.

## Scripts
All bundled scripts live in `Scripts/`:

- `unbrick.sh` — recovery script that reverses every Lock-with-Immutable-File operation. Auto-generated from `PrivacyTarget.allTargets`.
- `regenerate-app-icons.sh` — resizes a single source PNG into every slot in `AppIcon.appiconset` using the built-in `sips` tool.

## Tests
A unit-test target lives in `BananaBlitzTests/`. After `xcodegen generate`, run:

```bash
xcodebuild test -scheme BananaBlitz -destination 'platform=macOS'
```

Tests cover the `PrivacyCleaner` strategies, `FileSystemGuard` lock/unlock round-trips, `AppState` persistence, and `unbrick.sh` generation. CI runs the same command on every push (`.github/workflows/ci.yml`).

## Cutting a release
Releases are driven by GitHub Actions.

1. Run the **Release** workflow (`.github/workflows/release.yml`) from the Actions tab. Provide a `version` input like `1.1.0`.
2. The workflow bumps `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`, commits the change, and pushes a `v<version>` tag.
3. The pushed tag triggers the `archive` job in `ci.yml`, which:
   - Runs the test suite again.
   - Imports your Developer ID certificate (if configured), archives with Hardened Runtime, and signs the app.
   - Submits the signed bundle to Apple's notary service via `notarytool` (if configured) and staples the ticket.
   - Zips the result, uploads it as a workflow artifact, and creates a **draft** GitHub release for you to review and publish.

If signing or notarization secrets aren't set, the workflow still produces an unsigned `.zip` and drafts a release — the existing pre-1.0 behaviour. To enable full signing + notarization, add the following secrets to the repository (Settings → Secrets and variables → Actions):

| Secret | Contents |
| --- | --- |
| `APPLE_DEVELOPER_CERT_BASE64` | `base64 -i DeveloperID.p12` of your Developer ID Application certificate |
| `APPLE_DEVELOPER_CERT_PASSWORD` | The password used when exporting the `.p12` |
| `APPLE_TEAM_ID` | 10-char Team ID from your Apple Developer account |
| `KEYCHAIN_PASSWORD` | (optional) Password used for the temporary CI keychain |
| `AC_API_KEY_BASE64` | `base64 -i AuthKey_XXXXXX.p8` from App Store Connect → Users and Access → Keys |
| `AC_API_KEY_ID` | The 10-char Key ID shown next to the key |
| `AC_API_ISSUER_ID` | Issuer ID from the same App Store Connect page |

Once those are in place, every `v*` tag pushed (whether by `release.yml` or manually) produces a signed + notarized build ready to ship.

## Auto-updates (Sparkle)
The app integrates [Sparkle](https://github.com/sparkle-project/Sparkle) but is dormant until you finish signing + notarizing the app, since Sparkle relies on the code signature to verify updates. To enable updates:

1. `brew install --cask sparkle` to get the helper tools.
2. `generate_keys` — store the private key in the Keychain it prompts for, copy the public key into `Info.plist` under `SUPublicEDKey`.
3. Pick a stable HTTPS URL for `appcast.xml`. Add it to `Info.plist` as `SUFeedURL`.
4. After every release: `generate_appcast .` over your release artifacts directory and upload `appcast.xml` to the same host.

Until `SUFeedURL` is populated, the "Check for Updates" button in the About panel is disabled — the rest of the app still works.


## Manually locking a file (The visual way)
![manual](https://github.com/user-attachments/assets/e4b5a561-a46c-47f2-ad6a-c9db3b4f789d)
1. Open textedit and create a file
2. Remove the extension and ensure it is spelt **exactly** the same as the folder
3. Delete the folder in your ~/Library folder
4. Quickly drag the file across e.g. `Trial`
5. Right click on the file and 'lock' it

That's it


## License
MIT
