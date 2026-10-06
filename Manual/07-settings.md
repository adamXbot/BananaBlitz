# Settings

Open Settings with ⌘, or the gear in the menu bar popover. The window has five tabs.

## General

- **Open BananaBlitz at login.** Registers the app as a login item. The caption reports the real state: enabled, waiting for your approval in System Settings, or unavailable for this copy of the app.
- **Icon.** The menu bar glyph: the colour banana, the monochrome banana that matches the menu bar, or the Sparkles symbol.
- **Show a status badge on the icon.** The small dot that reports the schedule and cleaning state.
- **Open with ⌘⌃B from anywhere.** A global shortcut for the menu bar item, off by default.
- **After automatic cleans.** Silent, Summary or Detailed notifications. See [Schedule](05-schedule.md).
- **Full Disk Access.** Whether the permission is granted, with a button to the right pane of System Settings. The status refreshes while the tab is open.
- **About BananaBlitz.** The version, build, links and acknowledgements.

## Targets

Search by name, description or path, show one level at a time, and switch each target on or off. Expand a row for its side effect, path, strategy, **Verify state** and **Unlock**. See [Cleaning levels and targets](02-levels-and-targets.md).

## Schedule

- **Interval** and **Pause schedule**, with the time until the next clean.
- **Allow locking on schedule.** Lets unattended runs use Lock with Immutable File.
- **Default level.** Basic, Strong or Paranoid; choosing one re-selects its targets.
- **Strategy override.** Applies one strategy to every enabled target that supports it.

## Data

- **Re-scan All Targets.** Measures every target again and refreshes the sizes and lock states shown elsewhere.
- **Run Self-Test…** Walks every target and reports whether it is readable, missing, locked, denied (usually Full Disk Access) or an unexpected plain file. See [Troubleshooting](08-troubleshooting.md).
- **Preview Next Clean…** The dry run for the next scheduled clean.
- **Save Recovery Script…** and **Create Local Snapshot.** See [Recovery](06-recovery.md).
- **Export Cleaning History…** Saves the last 200 results as JSON or CSV, chosen by the file extension. Each row has the timestamp, target, strategy, success, bytes reclaimed, error and note.
- **Reset All Settings…** Clears everything and restarts setup, after a confirmation.

## Updates

The current version and channel, when updates were last checked, whether to check automatically and how often, **Check Now** and the release notes. Automatic checks are off until you turn them on. Updates use Sparkle and are dormant until a feed is published; see [Troubleshooting](08-troubleshooting.md).

## Keyboard shortcuts

**Help ▸ Keyboard Shortcuts** (⌘?) lists every shortcut: ⌘, for Settings, ⌘? for this list, ⌘H to hide, ⌘Q to quit, ⌘⌃B for the menu bar item when the global shortcut is on, and ⌘↩ for Blitz Now while the popover is open.
