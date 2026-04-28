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
If you need to revert the changes made by BananaBlitz, you can use the `unbrick.sh` script.

```bash
./unbrick.sh
```

This will remove the immutable flag from the locked directories and files, and recreate them as normal directories and files.

This may happen if you select the paranoid option.

The script bundled in this repo is **auto-generated** from the canonical `PrivacyTarget.allTargets` registry. To regenerate it for your local target list, open the app and use **Settings → Preferences → Data → Save Recovery Script…**, or call `UnbrickScriptGenerator.write(to:)` directly.

## Tests
A unit-test target lives in `BananaBlitzTests/`. After `xcodegen generate`, run:

```bash
xcodebuild test -scheme BananaBlitz -destination 'platform=macOS'
```

Tests cover the `PrivacyCleaner` strategies, `FileSystemGuard` lock/unlock round-trips, `AppState` persistence, and `unbrick.sh` generation. CI runs the same command on every push (`.github/workflows/ci.yml`).

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
