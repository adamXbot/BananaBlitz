# Changelog

## 1.1.0

First Developer ID signed, notarised release with in-app updates.

Fixed
- "Blitz Now" from the menu bar could not be confirmed: the confirmation was a sheet on the popover, and the first click inside it closed the popover before the button fired. It also reappeared on the next open with Blitz Now as the default button. The confirmation is now its own "Confirm Blitz" window.
- Opening the popover re-armed the schedule timer every time, so the next scheduled clean kept moving into the future.
- Accepting the pre-selected level in setup with Continue left no targets enabled, so the first blitz cleaned nothing.
- "Run Self-Test…" and "Preview Next Clean…" could open with an empty report.
- "Reset All Settings…" left the Settings window open behind setup.
- Cached target sizes were not refreshed after a clean; the "Next clean" countdown and "Cleaned … ago" status did not update while the popover stayed open.
- The permission step's explanation was truncated to one line; the per-target switch had no accessible name.

Added
- In-app updates via Sparkle (signed appcast at adamxweb.com; automatic checks are off until turned on in Settings ▸ Updates).
- An end-to-end UI test suite (`just ui-test`) that runs the real app against a throwaway home directory: setup, the menu bar, Settings, a real clean, the lock and unlock round trip, save panels, and light and dark screenshots of every surface.

## Unreleased

Add approved release notes with `just version VERSION NOTES_FILE` before shipping.
