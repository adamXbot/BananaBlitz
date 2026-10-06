# Strategies

Each target is cleaned with one of three strategies. Every target lists the strategies it supports; most support the first two, a few only one.

## Wipe Contents

Deletes every file inside the directory and leaves the directory in place. The responsible daemon recreates what it needs on its next run. For a single-file target the file itself is deleted. This is the default for almost every target and the only strategy an unattended run uses unless you opt in to locking (see [Schedule](05-schedule.md)).

## Delete Databases Only

Removes only database files, recursing into subfolders: `.db`, `.sqlite`, `.sqlite3`, `.sqlite-shm`, `.sqlite-wal` and `.segb`. Everything else is left alone. The least disruptive option, supported by KnowledgeC and Keyboard Profiling.

## Lock with Immutable File

Deletes the directory, then creates an empty file of the same name in its place and sets the user-immutable flag on it. The daemon finds a locked file where its directory used to be and cannot recreate it, so the data never comes back.

> This strategy is destructive. The lock is reversible, but the deleted contents are not. The dry run highlights these targets and offers to save the recovery script first.

A locked target is left alone by the other two strategies, and the dry run says so. The only ways to remove a lock are:

- **Unlock** on the target's row in Settings ▸ Targets, which clears the flag, deletes the lock file and recreates the empty directory.
- The recovery script. See [Recovery](06-recovery.md).

Re-applying a lock to a target that is already locked deletes nothing.

## Choosing strategies

- **Per target.** Expand a row in Settings ▸ Targets and pick from the strategy menu.
- **For every target at once.** Settings ▸ Schedule ▸ Strategy override applies one strategy to every enabled target that supports it. Targets that do not support it keep their own.

## Guardrails

Before any file operation BananaBlitz checks that the path resolves inside `~/Library` with no symlinked ancestor and refuses otherwise. Symlinks at the target itself are refused, and database files that are symlinks are skipped. Locking is atomic: if the immutable flag cannot be set, the original directory is restored.
