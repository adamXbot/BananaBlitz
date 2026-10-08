# Reverting what BananaBlitz did

The *Lock with Immutable File* strategy — the one the Paranoid level uses most —
deletes a directory and puts a locked empty file in its place. The lock is
reversible; the contents that were deleted are not, so keep backups.

Locks are only ever removed explicitly. The *Wipe Contents* and *Delete
Databases Only* strategies leave a locked target alone (so a scheduled run that
downgrades a lock to a wipe keeps the lock in place), and the dry run says so.

## Unlock from the app

Open **Settings → Targets**, expand a row that shows the lock icon, and click
**Unlock**. That clears the immutable flag, deletes the lock file and recreates
the empty directory so the system daemon can use the path again.

## Run the recovery script

```sh
./Scripts/unbrick.sh
```

It removes the immutable flag from every locked path, deletes the lock file, and
recreates the directory. Builds from `main` also bundle a copy at
`BananaBlitz.app/Contents/Resources/unbrick.sh`, and the cask template in this
repo, [`packaging/homebrew/bananablitz.rb`](../packaging/homebrew/bananablitz.rb),
runs that copy on uninstall so you are not left with locked directories after
`brew uninstall`. Homebrew runs the same hook on `brew reinstall` and on an
upgrade (`brew upgrade --greedy`, since the cask declares `auto_updates`), so
re-apply *Lock with Immutable File* in the app afterwards; scheduled runs only
re-lock if **Settings → Schedule → Allow locking on schedule** is on.
When you add or move a target, also update `writable_paths` in that template:
Homebrew sandboxes the hook and only lets it write to the paths listed there
(`HomebrewCaskTests` fails until they match `PrivacyTarget.allTargets`).
Releases up to v0.0.3 do not include the bundled copy; on those builds use
**Settings → Data → Save Recovery Script…** or this repo's copy.

## Regenerating it for your own target list

[`Scripts/unbrick.sh`](../Scripts/unbrick.sh) is **auto-generated** from the
canonical `PrivacyTarget.allTargets` registry — do not edit it by hand. To
produce one matching your current configuration, open the app and use
**Settings → Data → Save Recovery Script…**, or call
`UnbrickScriptGenerator.write(to:)` directly.

## Snapshots

During setup, or later from **Settings → Data → Create Local Snapshot**, BananaBlitz can take an APFS local snapshot via
`tmutil localsnapshot`. That does not need administrator privileges or a
configured Time Machine destination on modern macOS. The snapshot is taken when
you ask for it, not automatically before every clean, and it is a Time Machine
local snapshot — useful for restoring individual files, not a one-click bootable
rollback.

## Permissions

macOS protects `~/Library` from sandboxed apps, so BananaBlitz is built without
the App Sandbox and requires **Full Disk Access**. The onboarding wizard walks
you through granting it, and the in-app self-test (Settings → Data) tells
you which targets are unreachable if it was not granted.
