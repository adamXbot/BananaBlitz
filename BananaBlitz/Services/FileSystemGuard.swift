import Foundation

/// Handles the aggressive "replace with immutable file" strategy.
/// Replaces a directory with an empty file and sets the user-immutable flag
/// (`UF_IMMUTABLE`, equivalent to `chflags uchg`) so the corresponding daemon
/// cannot recreate its data store.
///
/// All targets live in `~/Library` (user-owned), so no privilege escalation is
/// required. The immutable flag is toggled in-process via `URLResourceValues`
/// instead of spawning `/usr/bin/chflags`.
final class FileSystemGuard {
    static let shared = FileSystemGuard()

    private let fileManager = FileManager.default
    private let log = AppLog.guardLog
    private let libraryRoot: String

    /// Test seam: when non-nil, immutable-flag toggling routes through this
    /// closure instead of `URLResourceValues`. Lets tests simulate a
    /// `chflags` failure (e.g. a hardened path) to exercise the crash-safe
    /// restore path in `lockTarget`. `nil` in production.
    private let immutableFlagSetter: ((String, Bool) throws -> Void)?

    /// Test seam: when non-nil, lock-file creation routes through this closure
    /// instead of `FileManager.createFile`. Lets tests simulate the
    /// `createFile == false` branch to exercise the restore path. `nil` in
    /// production.
    private let lockFileCreator: ((String) throws -> Void)?

    /// `libraryRoot` defaults to `~/Library` and is overridable for tests so
    /// the path-safety guard can be exercised against a temporary directory.
    init(
        libraryRoot: String = (NSHomeDirectory() as NSString).appendingPathComponent("Library"),
        immutableFlagSetter: ((String, Bool) throws -> Void)? = nil,
        lockFileCreator: ((String) throws -> Void)? = nil
    ) {
        self.libraryRoot = libraryRoot
        self.immutableFlagSetter = immutableFlagSetter
        self.lockFileCreator = lockFileCreator
    }

    // MARK: - Lock / Unlock

    /// Replace a target directory with an immutable empty file.
    ///
    /// Crash-safe: the original is moved aside to a sibling backup, the empty
    /// lock file is created and flagged, and only then is the backup deleted.
    /// If *any* step fails the original is moved back, so a partial failure
    /// (disk full, the daemon racing us, a `chflags` denial) can never leave
    /// the user with destroyed data and no replacement — the previous
    /// "delete first, create second" ordering could.
    func lockTarget(_ target: PrivacyTarget) throws {
        let path = target.resolvedPath
        try PathSafety.validateTargetPath(path, libraryRoot: libraryRoot)

        // Nothing here yet — no data to protect, so create the lock directly.
        // Still clean up a stray stub if flag-setting fails, so a failure never
        // leaves a bogus non-immutable file occupying the path.
        guard fileManager.fileExists(atPath: path) else {
            do {
                try createLockFile(at: path)
            } catch {
                try? fileManager.removeItem(atPath: path)
                throw error
            }
            return
        }

        // An existing lock file carries the immutable flag; clear it so the
        // path can be moved aside.
        if isLocked(target) {
            try setImmutableFlag(at: path, immutable: false)
        }

        // Move the original to a unique sibling (same directory → same volume
        // → atomic rename) so the path is free for the lock file.
        let backupPath = path + ".bananablitz-bak-\(UUID().uuidString)"
        try fileManager.moveItem(atPath: path, toPath: backupPath)

        do {
            try createLockFile(at: path)
        } catch {
            // Roll back: drop any half-created stub, then restore the original.
            try? fileManager.removeItem(atPath: path)
            guard restoreBackup(from: backupPath, to: path) else {
                // Could not put the original back (e.g. the daemon recreated
                // `path`). The user's data is NOT lost — it's at `backupPath` —
                // but surface that explicitly instead of only logging.
                throw BananaBlitzError.lockRollbackFailed(path: path, backupPath: backupPath, underlying: error.localizedDescription)
            }
            throw error
        }

        // Lock is in place — the replacement succeeded. A leftover backup is
        // harmless clutter (never data loss), so cleanup failure does not fail
        // the operation.
        do {
            try fileManager.removeItem(atPath: backupPath)
        } catch {
            log.error("Locked \(path, privacy: .public) but could not remove backup \(backupPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Create an empty file at `path` and set the user-immutable flag.
    private func createLockFile(at path: String) throws {
        if let lockFileCreator {
            try lockFileCreator(path)
        } else {
            guard fileManager.createFile(atPath: path, contents: nil, attributes: nil) else {
                throw BananaBlitzError.failedToCreateLockFile(path)
            }
        }
        try setImmutableFlag(at: path, immutable: true)
    }

    /// Restore the moved-aside original after a failed lock. Returns `false`
    /// (and logs) if the move back fails — the original then remains at the
    /// backup path.
    @discardableResult
    private func restoreBackup(from backupPath: String, to path: String) -> Bool {
        do {
            try fileManager.moveItem(atPath: backupPath, toPath: path)
            return true
        } catch {
            log.error("CRITICAL: could not restore \(backupPath, privacy: .public) to \(path, privacy: .public): \(error.localizedDescription, privacy: .public). Original data remains at the backup path.")
            return false
        }
    }

    /// Remove the immutable flag, delete the lock file, and recreate the directory.
    func unlockTarget(_ target: PrivacyTarget) throws {
        let path = target.resolvedPath
        try PathSafety.validateTargetPath(path, libraryRoot: libraryRoot)

        if fileManager.fileExists(atPath: path) {
            try setImmutableFlag(at: path, immutable: false)
            try fileManager.removeItem(atPath: path)
        }

        // Recreate as directory (unless target is a specific file)
        if !target.isSpecificFile {
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    // MARK: - Status

    /// Check if a target is currently locked (replaced with an immutable file).
    ///
    /// For a directory target, "locked" means the path exists, is *not* a directory,
    /// and has the user-immutable flag set. The earlier heuristic only checked
    /// "exists and isn't a dir," which falsely reported any unrelated stray file
    /// as locked.
    func isLocked(_ target: PrivacyTarget) -> Bool {
        let path = target.resolvedPath
        var isDir: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
            return false
        }

        if !target.isSpecificFile && isDir.boolValue {
            // Directory target that still exists as a directory — not locked.
            return false
        }

        // For both directory targets that have been collapsed to a file, and for
        // specific-file targets, "locked" requires the user-immutable flag.
        return isUserImmutable(at: path)
    }

    // MARK: - Immutable Flag

    /// Read the user-immutable flag using URLResourceValues.
    private func isUserImmutable(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        do {
            let values = try url.resourceValues(forKeys: [.isUserImmutableKey])
            return values.isUserImmutable ?? false
        } catch {
            log.debug("Failed to read isUserImmutable for \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Set or clear the user-immutable flag (`UF_IMMUTABLE`) without spawning
    /// a subprocess. Equivalent to `chflags uchg` / `chflags nouchg`.
    private func setImmutableFlag(at path: String, immutable: Bool) throws {
        if let immutableFlagSetter {
            try immutableFlagSetter(path, immutable)
            return
        }
        var url = URL(fileURLWithPath: path)
        var values = URLResourceValues()
        values.isUserImmutable = immutable
        do {
            try url.setResourceValues(values)
        } catch {
            log.error("Failed to \(immutable ? "set" : "clear", privacy: .public) immutable flag at \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw BananaBlitzError.immutableFlagFailed(path, error.localizedDescription)
        }
    }

}

// MARK: - Errors

enum BananaBlitzError: LocalizedError {
    case failedToCreateLockFile(String)
    case immutableFlagFailed(String, String)
    case refusedOutsideLibrary(String)
    case refusedSymlink(String)
    case lockRollbackFailed(path: String, backupPath: String, underlying: String)

    var errorDescription: String? {
        switch self {
        case .failedToCreateLockFile(let path):
            return "Failed to create lock file at \(path)"
        case .immutableFlagFailed(let path, let detail):
            return "Failed to toggle immutable flag on \(path): \(detail)"
        case .refusedOutsideLibrary(let path):
            return "Refusing to operate on path outside ~/Library: \(path)"
        case .refusedSymlink(let path):
            return "Refusing to operate on symlink at \(path)"
        case .lockRollbackFailed(let path, let backupPath, let underlying):
            return "Locking \(path) failed (\(underlying)) and the original could not be restored automatically. Your data is preserved at \(backupPath)."
        }
    }
}
