import Foundation

/// A pre-resolved unit of work passed to `PrivacyCleaner.cleanAll(jobs:)`.
///
/// Constructing jobs on the main thread before dispatching to a background
/// queue avoids reading `@Published` properties on the wrong actor — which
/// the previous `cleanAll(state:)` signature did.
struct CleaningJob {
    let target: PrivacyTarget
    let strategy: CleaningStrategy
}

/// The cleaning back-end the scheduler drives. Abstracted so a spy can be
/// injected in tests, letting the real async clean/complete/release path run
/// without touching `~/Library`.
protocol CleaningEngine {
    func cleanAll(jobs: [CleaningJob]) -> [CleaningResult]
}

/// Core cleaning engine that executes cleaning operations on privacy targets.
///
/// All public functions are pure with respect to global mutable state — the
/// caller is responsible for snapshotting the current set of enabled targets
/// and their strategies on the main thread before dispatching here.
///
/// Two invariants every strategy honours:
///   * A target that is currently locked by BananaBlitz is left untouched by
///     the non-locking strategies. Cleaning never removes a lock as a side
///     effect; `unlock(target:)` is the only code path that does.
///   * `bytesReclaimed` is measured (size before minus size after), never
///     assumed from the pre-clean size.
final class PrivacyCleaner: CleaningEngine {
    static let shared = PrivacyCleaner()

    /// `CleaningResult.note` attached to a successful no-op on a locked target.
    static let lockedSkipNote = "Locked by BananaBlitz — skipped"

    private let fileManager: FileManager
    private let guardService: FileSystemGuard
    private let libraryRoot: String
    private let log = AppLog.cleaner

    init(
        libraryRoot: String = PathSafety.defaultLibraryRoot,
        fileManager: FileManager = .default,
        guardService: FileSystemGuard? = nil
    ) {
        self.libraryRoot = libraryRoot
        self.fileManager = fileManager
        self.guardService = guardService ?? FileSystemGuard(libraryRoot: libraryRoot)
    }

    /// Execute a cleaning operation on a single target with the given strategy.
    func clean(target: PrivacyTarget, strategy: CleaningStrategy) -> CleaningResult {
        var startSize: Int64 = 0
        do {
            try PathSafety.validateTargetPath(target.resolvedPath, libraryRoot: libraryRoot)
            startSize = TargetScanner.shared.targetSize(target)

            var note: String?
            switch strategy {
            case .wipeContents:
                note = try wipeContents(of: target)
            case .replaceWithFile:
                try guardService.lockTarget(target)
            case .deleteDatabases:
                note = try deleteDatabases(in: target)
            }

            let reclaimed = max(0, startSize - TargetScanner.shared.targetSize(target))
            if let note {
                log.info("Skipped \(target.id, privacy: .public): \(note, privacy: .public)")
            } else {
                log.debug("Cleaned \(target.id, privacy: .public) via \(strategy.rawValue, privacy: .public): \(reclaimed) bytes")
            }
            return CleaningResult(
                targetID: target.id,
                strategy: strategy,
                bytesReclaimed: reclaimed,
                success: true,
                note: note
            )
        } catch {
            // Report whatever was actually removed before the failure, so a
            // wipe that got halfway is not recorded as "nothing happened".
            let reclaimed = startSize > 0
                ? max(0, startSize - TargetScanner.shared.targetSize(target))
                : 0
            log.error("Cleaning \(target.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return CleaningResult(
                targetID: target.id,
                strategy: strategy,
                bytesReclaimed: reclaimed,
                success: false,
                error: error.localizedDescription
            )
        }
    }

    /// Clean every job in order. Designed to run on a background queue.
    func cleanAll(jobs: [CleaningJob]) -> [CleaningResult] {
        jobs.map { clean(target: $0.target, strategy: $0.strategy) }
    }

    /// Explicitly remove a BananaBlitz lock: clears the immutable flag,
    /// deletes the lock file and recreates the (empty) directory so the
    /// system daemon can use the path again. This is the only way a lock is
    /// removed from inside the app.
    func unlock(target: PrivacyTarget) throws {
        try guardService.unlockTarget(target)
        log.info("Unlocked \(target.id, privacy: .public)")
    }

    // MARK: - Strategy Implementations

    /// Delete all contents of a directory (or a specific file).
    /// Symlinks at the top level of the directory are removed (the link
    /// itself, not the target), but never followed.
    ///
    /// Returns a note when the target was deliberately left alone.
    private func wipeContents(of target: PrivacyTarget) throws -> String? {
        let path = target.resolvedPath
        try PathSafety.validateTargetPath(path, libraryRoot: libraryRoot)

        guard fileManager.fileExists(atPath: path) else { return nil }

        // A lock is an explicit user decision. A wipe — including the wipe a
        // scheduled run downgrades a lock to — must never undo it.
        if guardService.isLocked(target) { return Self.lockedSkipNote }

        if target.isSpecificFile {
            try fileManager.removeItem(atPath: path)
            return nil
        }

        let contents = try fileManager.contentsOfDirectory(atPath: path)
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            // `removeItem` only removes the link itself for symlinks, but
            // log the case so suspicious filesystem layouts are visible.
            if PathSafety.isSymbolicLink(at: itemPath) {
                log.debug("Removing symlink (not following): \(itemPath, privacy: .public)")
            }
            try fileManager.removeItem(atPath: itemPath)
        }
        return nil
    }

    /// Delete only database files (see `CleaningStrategy.databaseExtensions`).
    ///
    /// Returns a note when the target was deliberately left alone.
    private func deleteDatabases(in target: PrivacyTarget) throws -> String? {
        let path = target.resolvedPath
        let dbExtensions = CleaningStrategy.databaseExtensions
        try PathSafety.validateTargetPath(path, libraryRoot: libraryRoot)

        guard fileManager.fileExists(atPath: path) else { return nil }

        if guardService.isLocked(target) { return Self.lockedSkipNote }

        if target.isSpecificFile {
            let ext = (path as NSString).pathExtension.lowercased()
            if dbExtensions.contains(ext) {
                try fileManager.removeItem(atPath: path)
            }
            return nil
        }

        let root = URL(fileURLWithPath: path, isDirectory: true)
        let keys: [URLResourceKey] = [.isSymbolicLinkKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else { return nil }

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            if values?.isSymbolicLink == true {
                log.debug("Skipping database-looking symlink: \(fileURL.path, privacy: .public)")
                continue
            }
            guard values?.isRegularFile == true else { continue }

            let ext = fileURL.pathExtension.lowercased()
            if dbExtensions.contains(ext) {
                try PathSafety.assertInsideLibrary(fileURL.path, libraryRoot: libraryRoot)
                try fileManager.removeItem(at: fileURL)
            }
        }
        return nil
    }
}
