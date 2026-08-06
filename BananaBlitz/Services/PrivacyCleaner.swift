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
final class PrivacyCleaner: CleaningEngine {
    static let shared = PrivacyCleaner()

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
        do {
            try PathSafety.validateTargetPath(target.resolvedPath, libraryRoot: libraryRoot)
            let startSize = TargetScanner.shared.targetSize(target)

            switch strategy {
            case .wipeContents:
                try wipeContents(of: target)
            case .replaceWithFile:
                try guardService.lockTarget(target)
            case .deleteDatabases:
                try deleteDatabases(in: target)
            }

            log.debug("Cleaned \(target.id, privacy: .public) via \(strategy.rawValue, privacy: .public): \(startSize) bytes")
            return CleaningResult(
                targetID: target.id,
                strategy: strategy,
                bytesReclaimed: startSize,
                success: true
            )
        } catch {
            log.error("Cleaning \(target.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return CleaningResult(
                targetID: target.id,
                strategy: strategy,
                bytesReclaimed: 0,
                success: false,
                error: error.localizedDescription
            )
        }
    }

    /// Clean every job in order. Designed to run on a background queue.
    func cleanAll(jobs: [CleaningJob]) -> [CleaningResult] {
        jobs.map { clean(target: $0.target, strategy: $0.strategy) }
    }

    // MARK: - Strategy Implementations

    /// Delete all contents of a directory (or a specific file).
    /// Symlinks at the top level of the directory are removed (the link
    /// itself, not the target), but never followed.
    private func wipeContents(of target: PrivacyTarget) throws {
        let path = target.resolvedPath
        try PathSafety.validateTargetPath(path, libraryRoot: libraryRoot)

        if target.isSpecificFile {
            if fileManager.fileExists(atPath: path) {
                if guardService.isLocked(target) {
                    try guardService.unlockTarget(target)
                } else {
                    try fileManager.removeItem(atPath: path)
                }
            }
            return
        }

        guard fileManager.fileExists(atPath: path) else { return }

        if guardService.isLocked(target) {
            try guardService.unlockTarget(target)
            return
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
    }

    /// Delete only database files (.db, .sqlite, .sqlite3, .sqlite-shm, .sqlite-wal, .segb).
    private func deleteDatabases(in target: PrivacyTarget) throws {
        let path = target.resolvedPath
        let dbExtensions: Set<String> = ["db", "sqlite", "sqlite3", "sqlite-shm", "sqlite-wal", "segb"]
        try PathSafety.validateTargetPath(path, libraryRoot: libraryRoot)

        if target.isSpecificFile {
            let ext = (path as NSString).pathExtension.lowercased()
            if dbExtensions.contains(ext) && fileManager.fileExists(atPath: path) {
                if guardService.isLocked(target) {
                    try guardService.unlockTarget(target)
                } else {
                    try fileManager.removeItem(atPath: path)
                }
            }
            return
        }

        guard fileManager.fileExists(atPath: path) else { return }

        if guardService.isLocked(target) {
            try guardService.unlockTarget(target)
            return
        }

        let root = URL(fileURLWithPath: path, isDirectory: true)
        let keys: [URLResourceKey] = [.isSymbolicLinkKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else { return }

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
    }
}
