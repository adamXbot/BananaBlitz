# Troubleshooting

## Full Disk Access is not detected

BananaBlitz checks access by reading a protected path. If System Settings shows it on but the app still says *Not granted*:

1. Make sure the entry you toggled under Privacy & Security ▸ Full Disk Access is **BananaBlitz**, not another app.
2. Quit and reopen BananaBlitz. macOS sometimes needs a relaunch before it applies the grant.
3. If you moved or rebuilt the app, remove the old entry with the minus button and add the new copy.

Without access, protected targets scan as 0 bytes and show *needs access* in the wizard, and cleans report *Permission denied*.

## A target says "not present on this Mac"

The path does not exist here, which usually means that feature has never run or this macOS version keeps it elsewhere. Nothing to clean; the row is informational.

## The self-test reports "denied"

The path exists but cannot be read. Almost always Full Disk Access, above. The self-test is in Settings ▸ Data ▸ **Run Self-Test…**.

## The self-test reports "unexpected file"

The path is a plain file where a directory was expected, and it is not one of BananaBlitz's locks. Something else put it there; BananaBlitz leaves it alone. Remove it in Finder if you are sure, then **Verify state** on the target's row.

## A clean reports failures

The popover's result line turns orange and the dashboard banner lists the targets and the reasons. The same reason is kept on each row of the recent activity list and in the exported history. Common causes are a missing permission, a path that fails the guardrails (outside `~/Library`, or through a symlink), or a file in use.

## The schedule did not run

- Check the popover: the status line says *paused* if it is, and the badge on the banana is grey.
- The interval is **Manual only** if the next-clean line is missing.
- The app must be running. Turn on **Open BananaBlitz at login** in Settings ▸ General and, if the caption says it is waiting for approval, approve it under System Settings ▸ General ▸ Login Items.
- A clean skipped because another was running moves to the next interval.

## Notifications never appear

Settings ▸ General says, under the picker, whether macOS has notifications turned off for BananaBlitz or has never been asked, with a button to fix each. Failure alerts are always sent regardless of the chosen style.

## Something I locked needs to come back

Expand the target in Settings ▸ Targets and click **Unlock**, or run the recovery script. See [Recovery](06-recovery.md).

## Check for Updates does nothing

In-app updates use Sparkle but are dormant until a release feed and signing key are published with the app. Until then **Check for Updates…** and **Check Now** have nothing to check, and *Last checked* stays at *Never*. New versions are announced on the project's releases page, linked from the Updates tab and from About.

## Reporting a problem

**About BananaBlitz ▸ Report an Issue** opens the issue tracker. Include the version and build from About (click the build line to copy it), the macOS version, and the self-test result if the problem is about a target.
