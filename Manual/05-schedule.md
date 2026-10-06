# Schedule

BananaBlitz can clean on its own at a fixed interval. Set it up in the wizard or in Settings ▸ Schedule.

## Interval

Every 1, 2, 4, 8, 12 or 24 hours, or **Manual only**, which never cleans unless you click Blitz Now. The popover and the Schedule tab show when the next clean is due. **Pause schedule** stops the timer without forgetting the interval; Resume in the popover starts it again.

## Catch-up

Timers do not fire while the Mac is asleep or while the app is closed, so BananaBlitz re-checks on wake and at launch: if the last clean is older than the interval, it runs a catch-up clean straight away. An install that has never cleaned is not overdue; it waits for its first scheduled fire.

## Unattended runs and locking

Scheduled, catch-up and wake-triggered cleans run with no confirmation. By default any target set to Lock with Immutable File is downgraded to Wipe Contents for those runs, so nothing is deleted-and-locked without you watching. **Allow locking on schedule** in Settings ▸ Schedule turns the downgrade off. Already-locked targets are left alone either way.

## Notifications

After an automatic clean BananaBlitz can post a notification, chosen in Settings ▸ General:

- **Silent.** Nothing after a successful clean.
- **Summary.** One notification: targets cleaned, bytes reclaimed, locked targets skipped.
- **Detailed.** One line per target with its result.

A clean with at least one failure always sends an alert, even in Silent mode, because silent failure is worse for a privacy tool than an unwanted notification. If macOS has notifications turned off for BananaBlitz, or has never been asked, the General tab says so under the picker.

## Open at login

For the schedule to run, BananaBlitz has to be running. **Open BananaBlitz at login** in Settings ▸ General registers it as a login item with macOS; the caption under the switch reports what macOS actually has, including when it is waiting for your approval under System Settings ▸ General ▸ Login Items.
