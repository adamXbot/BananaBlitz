# BananaBlitz 🍌

BananaBlitz is a lightweight, stealthy native macOS utility that helps you reclaim your privacy by periodically cleaning up deep system telemetry databases, Siri intelligence metrics, and tracking logs within your `~/Library` folder.

Instead of disabling System Integrity Protection (SIP), BananaBlitz uses macOS native constructs (`chflags`) to selectively neuter unwanted directories and stop Apple daemons from logging metrics, without risking breaking your OS.

> [!CAUTION]
> **Use at your own risk.** BananaBlitz modifies system-generated files and directories within your `~/Library` folder using aggressive locking mechanisms (`chflags`). While designed to be non-destructive, the developers are not responsible for any data loss, system instability, or unexpected behavior resulting from the use of this utility. Always ensure you have a recent backup of your data.

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

## License
MIT
