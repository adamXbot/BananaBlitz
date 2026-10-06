# Getting started

BananaBlitz is a menu bar utility that clears telemetry, intelligence and tracking data out of your `~/Library` on a schedule you choose. It does not disable System Integrity Protection: it empties or locks specific folders using ordinary file operations and the user-immutable flag, the same thing `chflags uchg` sets.

> Some of these paths back real features, so cleaning them makes suggestions and predictions worse until they rebuild. Every target states its side effect before you enable it. See [Cleaning levels and targets](02-levels-and-targets.md).

## What you need

- macOS 14 or later.
- **Full Disk Access.** macOS protects `~/Library` from apps, so BananaBlitz ships without the App Sandbox and needs this permission to read and clean its targets. The setup wizard walks you through granting it under System Settings ▸ Privacy & Security ▸ Full Disk Access. A relaunch is sometimes needed before macOS applies it.

## First launch

The first time BananaBlitz runs it opens **Welcome to BananaBlitz**, a seven-step setup wizard:

1. **Welcome.** What the app does.
2. **Full Disk Access.** Opens System Settings and waits until access is granted. You can skip for now and grant it later from Settings ▸ General.
3. **Scan.** Measures every target so you can see what is there.
4. **Safety backup.** Optionally takes a Time Machine local snapshot. See [Recovery](06-recovery.md).
5. **Choose your level.** Basic, Strong or Paranoid pre-selects a set of targets.
6. **Set and forget.** Picks the cleaning interval and whether to open at login.
7. **Blitz.** Previews, then runs the first clean.

You can quit mid-way; the wizard reopens on the same step next launch. To run it again later choose **Help ▸ Welcome to BananaBlitz**.

## The menu bar item

BananaBlitz lives in the menu bar with no Dock icon. Click the banana to open the popover:

- The header shows the app's mark and name.
- A status line says when the last clean ran and when the next one is due, with Pause and Resume for the schedule.
- **Blitz Now** (⌘↩) previews what a clean would do, then runs it. See [Blitz Now and the dry run](04-blitz-now.md).
- The dashboard shows the total reclaimed, how many targets are enabled, the last clean, a banner when the last clean had failures, and the recent activity.
- A row per level shows how many of its targets are enabled and their size on disk.
- The footer has a gear that opens Settings (⌘,) and **Quit BananaBlitz** (⌘Q).

The banana carries a small badge when something needs attention: orange until setup is finished, blue during a clean, grey while the schedule is paused and green while it is armed. Turn the badge off, change the glyph, or enable the global shortcut ⌘⌃B in Settings ▸ General. See [Settings](07-settings.md).

## Windows and the Dock

While a window is open (Settings, About, this manual, Keyboard Shortcuts or the setup wizard) BananaBlitz appears in the Dock and the app switcher so the main menu works. When the last window closes it returns to the menu bar only.
