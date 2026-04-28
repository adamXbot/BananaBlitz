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

/// Core cleaning engine that executes cleaning operations on privacy targets.
///
/// All public functions are pure with respect to global mutable state — the
/// caller is responsible for snapshotting the current set of enabled targets
/// and their strategies on the main thread before dispatching here.
final class PrivacyCleaner {
    static let shared = PrivacyCleaner()

    private let fileManager = FileManager.default
    private let log = AppLog.cleaner

    /// Execute a cleaning operation on a single target with the given strategy.
    func clean(target: PrivacyTarget, strategy: CleaningStrategy) -> CleaningResult {
        let startSize = TargetScanner.shared.targetSize(target)

        do {
            switch strategy {
            case .wipeContents:
                try wipeContents(of: target)
            case .replaceWithFile:
                try FileSystemGuard.shared.lockTarget(target)
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

        if target.isSpecificFile {
            if fileManager.fileExists(atPath: path) {
                if FileSystemGuard.shared.isLocked(target) {
                    try FileSystemGuard.shared.unlockTarget(target)
                } else {
                    try fileManager.removeItem(atPath: path)
                }
            }
            return
        }

        guard fileManager.fileExists(atPath: path) else { return }

        if FileSystemGuard.shared.isLocked(target) {
            try FileSystemGuard.shared.unlockTarget(target)
            return
        }

        // Refuse to wipe contents if the path itself is a symlink — that
        // would mean we're chasing a link out of the target's tree.
        let url = URL(fileURLWithPath: path)
        if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            log.error("Refusing to wipe symlink at \(path, privacy: .public)")
            return
        }

        let contents = try fileManager.contentsOfDirectory(atPath: path)
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            // `removeItem` only removes the link itself for symlinks, but
            // log the case so suspicious filesystem layouts are visible.
            let itemURL = URL(fileURLWithPath: itemPath)
            if (try? itemURL.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
                log.debug("Removing symlink (not following): \(itemPath, privacy: .public)")
            }
            try fileManager.removeItem(atPath: itemPath)
        }
    }

    /// Delete only database files (.db, .sqlite, .sqlite3, .sqlite-shm, .sqlite-wal, .segb).
    private func deleteDatabases(in target: PrivacyTarget) throws {
        let path = target.resolvedPath
        let dbExtensions: Set<String> = ["db", "sqlite", "sqlite3", "sqlite-shm", "sqlite-wal", "segb"]

        if target.isSpecificFile {
            let ext = (path as NSString).pathExtension.lowercased()
            if dbExtensions.contains(ext) && fileManager.fileExists(atPath: path) {
                if FileSystemGuard.shared.isLocked(target) {
                    try FileSystemGuard.shared.unlockTarget(target)
                } else {
                    try fileManager.removeItem(atPath: path)
                }
            }
            return
        }

        guard fileManager.fileExists(atPath: path) else { return }

        if FileSystemGuard.shared.isLocked(target) {
            try FileSystemGuard.shared.unlockTarget(target)
            return
        }

        guard let enumerator = fileManager.enumerator(atPath: path) else { return }
        while let file = enumerator.nextObject() as? String {
            let ext = (file as NSString).pathExtension.lowercased()
            if dbExtensions.contains(ext) {
                let fullPath = (path as NSString).appendingPathComponent(file)
                try fileManager.removeItem(atPath: fullPath)
            }
        }
    }
}
