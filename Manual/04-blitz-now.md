# Blitz Now and the dry run

**Blitz Now** in the menu bar popover (or ⌘↩ while it is open) runs a clean of every enabled target with its chosen strategy. Nothing is touched until you confirm.

## The preview

Clicking Blitz Now first runs a **dry run**: for every enabled target it reports the action that would run, the number of items at risk and their size, without changing anything. The sheet lists:

- **Targets, Items, Bytes** totals at the top.
- One row per target with its action: *Empty directory contents*, *Delete file*, *Delete database files only* or *Replace with locked empty file*.
- A **DELETES, THEN LOCKS** badge on any target set to Lock with Immutable File, and a **Save Recovery Script…** button when there is at least one.
- Locked targets, shown as *Locked by BananaBlitz, skipped* (or *Already locked* when the strategy is a lock).
- Targets whose path fails the guardrails, shown as *Blocked* with the reason.

**Blitz Now** in the sheet runs the clean; **Cancel** or **Close** does nothing.

## While it runs

The banana in the menu bar shows a blue bolt badge and the popover's button reads *Cleaning…*. Only one clean runs at a time: a scheduled clean that fires during a manual one is skipped and the countdown moves to the next opportunity.

## The result

When the clean finishes the popover shows one line: how many targets were cleaned, how much was reclaimed, and how many locked targets were skipped. If any target failed the line turns orange and the dashboard below shows a banner naming up to three failures and why. Every result is recorded in the recent activity list and in the cleaning history (see [Settings](07-settings.md) for exporting it).

Bytes reclaimed are measured: the size on disk before the operation minus the size after, never assumed from the scan.

## Previewing the scheduled clean

Settings ▸ Data ▸ **Preview Next Clean…** runs the same dry run for the next scheduled clean, including the unattended downgrade of locks to wipes, so it shows exactly what the schedule will do.
