# Recovery

Wipe Contents and Delete Databases Only remove data that the system regenerates; there is nothing to undo beyond the rebuild. Lock with Immutable File is different: the directory is gone and a locked file stands in its place until you remove it. Keep backups.

## Unlock from the app

Open Settings ▸ Targets, expand a row that shows the lock icon and click **Unlock**. That clears the immutable flag, deletes the lock file and recreates the empty directory so the daemon can use the path again. Cleaning never does this on its own.

## The recovery script

**Save Recovery Script…** (File menu, Settings ▸ Data, or the dry run sheet) writes `unbrick.sh`, a shell script that reverses every lock BananaBlitz can apply. It is generated from the same target registry the app cleans from, so it cannot drift from the list above. Run it in Terminal:

```
bash ~/Downloads/unbrick.sh
```

For every locked target it removes the immutable flag, deletes the lock file and recreates the directory. A single-file target is removed only when it carries the immutable flag. If it unlocked anything, it then restarts the menu bar services so the system picks the paths up again; otherwise it prints "No locked targets found." and leaves them running. A copy also ships inside the app at `BananaBlitz.app/Contents/Resources/unbrick.sh`, and the Homebrew cask runs it on uninstall.

## Local snapshots

**Create Local Snapshot** (the setup wizard or Settings ▸ Data) asks Time Machine for an APFS local snapshot with `tmutil localsnapshot`. It needs no administrator password and no backup destination. The snapshot is taken when you ask for it, not before every clean, and it is a Time Machine local snapshot: useful for restoring individual files by entering Time Machine, not a one-click rollback of the whole system.

## Resetting the app

Settings ▸ Data ▸ **Reset All Settings…** clears the cleaning history, the reclaimed total, your target selection, strategies and schedule, then restarts the setup wizard. It asks first. Locked directories stay locked; use Unlock or the recovery script for those.
