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

    /// `libraryRoot` defaults to `~/Library` and is overridable for tests so
    /// the path-safety guard can be exercised against a temporary directory.
    init(libraryRoot: String = (NSHomeDirectory() as NSString).appendingPathComponent("Library")) {
        self.libraryRoot = libraryRoot
    }

    // MARK: - Lock / Unlock

    /// Replace a target directory with an immutable empty file.
    func lockTarget(_ target: PrivacyTarget) throws {
        try assertInsideLibrary(target.resolvedPath)
        let path = target.resolvedPath

        // Refuse to operate on a symlink — that would follow the link out
        // of the target's tree.
        let url = URL(fileURLWithPath: path)
        if let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]),
           values.isSymbolicLink == true {
            throw BananaBlitzError.refusedSymlink(path)
        }

        // Remove existing directory or file
        if fileManager.fileExists(atPath: path) {
            // If already locked (is a file with uchg), remove flag first
            if isLocked(target) {
                try setImmutableFlag(at: path, immutable: false)
            }
            try fileManager.removeItem(atPath: path)
        }

        // Create empty file at the same path
        guard fileManager.createFile(atPath: path, contents: nil, attributes: nil) else {
            throw BananaBlitzError.failedToCreateLockFile(path)
        }

        // Set user immutable flag
        try setImmutableFlag(at: path, immutable: true)
    }

    /// Remove the immutable flag, delete the lock file, and recreate the directory.
    func unlockTarget(_ target: PrivacyTarget) throws {
        try assertInsideLibrary(target.resolvedPath)
        let path = target.resolvedPath

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

    // MARK: - Path Safety

    /// Refuse any operation whose resolved path would escape `~/Library`.
    /// Cheap belt-and-braces guard against future code that lets a path leak through.
    private func assertInsideLibrary(_ path: String) throws {
        // Use standardised paths to collapse `..` segments.
        let standardised = (path as NSString).standardizingPath
        let standardisedLibrary = (libraryRoot as NSString).standardizingPath
        if standardised == standardisedLibrary { return }
        if standardised.hasPrefix(standardisedLibrary + "/") { return }
        throw BananaBlitzError.refusedOutsideLibrary(path)
    }
}

// MARK: - Errors

enum BananaBlitzError: LocalizedError {
    case failedToCreateLockFile(String)
    case immutableFlagFailed(String, String)
    case refusedOutsideLibrary(String)
    case refusedSymlink(String)

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
        }
    }
}
