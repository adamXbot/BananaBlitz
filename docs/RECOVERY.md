# Reverting what BananaBlitz did

The *Lock with Immutable File* strategy — the one the Paranoid level uses most —
deletes a directory and puts a locked empty file in its place. The lock is
reversible; the contents that were deleted are not, so keep backups.

## Run the recovery script

```sh
./Scripts/unbrick.sh
```

It removes the immutable flag from every locked path, deletes the lock file, and
recreates the directory. A copy of the script also ships inside the app bundle at
`BananaBlitz.app/Contents/Resources/unbrick.sh`. The canonical cask in this repo,
[`Casks/bananablitz.rb`](../Casks/bananablitz.rb), runs that copy on uninstall so
you are not left with locked directories after `brew uninstall`.

## Regenerating it for your own target list

[`Scripts/unbrick.sh`](../Scripts/unbrick.sh) is **auto-generated** from the
canonical `PrivacyTarget.allTargets` registry — do not edit it by hand. To
produce one matching your current configuration, open the app and use
**Settings → Preferences → Data → Save Recovery Script…**, or call
`UnbrickScriptGenerator.write(to:)` directly.

## Snapshots

Before a clean, BananaBlitz can take an APFS local snapshot via
`tmutil localsnapshot /`. That does not need administrator privileges on modern
macOS. It is a Time Machine local snapshot — useful for restoring individual
files, not a one-click bootable rollback.

## Permissions

macOS protects `~/Library` from sandboxed apps, so BananaBlitz is built without
the App Sandbox and requires **Full Disk Access**. The onboarding wizard walks
you through granting it, and the in-app self-test (Settings → Preferences) tells
you which targets are unreachable if it was not granted.
