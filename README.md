<div align="center">

<img src="BananaBlitz/Assets.xcassets/AppIcon.appiconset/AppIcon256x256.png" alt="BananaBlitz" width="128">

# BananaBlitz

A menu-bar macOS utility that periodically clears telemetry, intelligence and tracking data out of your `~/Library`.

[![Project status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2FadamXbot%2F.github%2Fmain%2Fbadges%2FBananaBlitz.json)](https://github.com/adamXbot/.github/blob/main/STATUS.md#bananablitz)
[![Release](https://img.shields.io/github/v/release/adamXbot/BananaBlitz?label=release)](https://github.com/adamXbot/BananaBlitz/releases/latest)
[![Licence](https://img.shields.io/github/license/adamXbot/BananaBlitz?label=licence)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/adamXbot/BananaBlitz/ci.yml?branch=main&label=ci)](https://github.com/adamXbot/BananaBlitz/actions/workflows/ci.yml)

</div>

<!-- disclosure:start -->
> [!WARNING]
> **Pre-1.0 — no stable release yet.** Anything can change in any release, including a patch: APIs, CLI flags, config keys, file formats, and data already on disk. Keep your own backups.
> **Project status.** The badge above is generated from [the adamXbot status list](https://github.com/adamXbot/.github/blob/main/STATUS.md), which says what I promise for this project and every other one.
<!-- disclosure:end -->

> [!CAUTION]
> **Use at your own risk.** BananaBlitz modifies system-generated files and directories within your `~/Library` folder. The "Lock with Immutable File" strategy *is* destructive — it deletes the original directory and replaces it with a locked empty file — but the operation is reversible via the in-app "Save Recovery Script…" button (Settings → Preferences → Data) or the bundled [`Scripts/unbrick.sh`](Scripts/unbrick.sh). The developers are not responsible for any data loss, system instability, or unexpected behaviour resulting from the use of this utility. Always ensure you have a recent backup of your data.

---

macOS writes a great deal about you into `~/Library`: analytics payloads, Siri and Biome intelligence databases, screen-time records and daemon caches. Most of it is regenerated whether you want it or not.

BananaBlitz sits in the menu bar and clears those paths on a schedule you choose. Rather than disabling System Integrity Protection, it uses a native macOS construct — the user-immutable flag, the same thing `chflags uchg` sets — to selectively neuter directories so the responsible daemon cannot recreate them.

Some of these paths back real features, so cleaning them makes suggestions and predictions worse until they rebuild. Every target states its side effect before you enable it.

## What it does

- **Three cleaning levels.** Basic (8 targets — analytics and metrics only), Strong (adds 10 intelligence databases), and Paranoid (adds 8 more, including screen time and Siri profiling). 26 targets in total, each with a stated side effect.
- **Three strategies per target.** *Wipe Contents* empties the directory and lets the daemon rebuild it; *Delete Databases Only* removes just `.db` / `.sqlite` / `.segb` files; *Lock with Immutable File* replaces the directory with a locked empty file the daemon cannot recreate.
- **Dry run.** Reports every target, the action that would run, and the item count and byte size at risk, before anything is touched.
- **Scheduled cleaning.** Every 1, 2, 4, 8, 12 or 24 hours, or manual only. The scheduler re-checks after the Mac wakes and runs a catch-up clean if a fire was missed while the app was closed. Unattended runs downgrade locking to a plain wipe unless you explicitly allow it.
- **Menu bar only.** No dock icon. An optional global shortcut (⌘⌃B) opens it from anywhere — off by default, enabled in Settings → Preferences.
- **Recovery built in.** [`Scripts/unbrick.sh`](Scripts/unbrick.sh) reverses every lock and is generated from the same target registry the app cleans from, so it cannot drift. The app can also take an APFS local snapshot before it cleans.
- **Guardrails.** Filesystem operations are refused unless the path resolves inside `~/Library` with no symlinked ancestor. A self-test reports which targets are reachable, missing, locked, or blocked by missing permissions.

## Get it

**Homebrew cask:**

```sh
brew install adamxbot/tap/bananablitz
```

The tap is currently serving 0.0.2 while the latest release is v0.0.3 — if you want the newest build today, take the DMG.

**Direct download:** the signed and notarised DMG attached to the [latest release](https://github.com/adamXbot/BananaBlitz/releases/latest).

Requires macOS 14 or later. Because macOS protects `~/Library` from sandboxed apps, BananaBlitz ships without the App Sandbox and needs **Full Disk Access** — the onboarding wizard walks you through granting it.

In-app updates use [Sparkle](https://github.com/sparkle-project/Sparkle) but are dormant: `SUFeedURL` and `SUPublicEDKey` are not yet in `Info.plist`, so "Check for Updates…" stays disabled. Everything else works. [`docs/RELEASES.md`](docs/RELEASES.md) covers what turning it on requires.

## Docs

There is no docs site. Everything lives in the repo:

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — building, testing, and what each bundled script does.
- [`docs/RELEASES.md`](docs/RELEASES.md) — signing, notarisation, the Sparkle appcast, and updating the Homebrew cask.
- [`docs/RECOVERY.md`](docs/RECOVERY.md) — reverting the locks, snapshots, and the Full Disk Access requirement.
- [`docs/MANUAL-LOCKING.md`](docs/MANUAL-LOCKING.md) — locking a single path by hand in Finder, without the app.
- [`SECURITY.md`](SECURITY.md) — how to report a vulnerability.

## Contributing

The project file is generated by XcodeGen from [`project.yml`](project.yml), so `.pbxproj` conflicts do not happen. CI runs exactly two commands on every push and pull request to `main`:

```sh
xcodegen generate
xcodebuild test -scheme BananaBlitz -destination 'platform=macOS' -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

With [`just`](https://github.com/casey/just) installed those are `just setup` and `just test`. Full details, including the recipe list and the script inventory, are in [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Licence

MIT — see [LICENSE](LICENSE).
