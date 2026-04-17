import Foundation

/// Core cleaning engine that executes cleaning operations on privacy targets.
class PrivacyCleaner {
    static let shared = PrivacyCleaner()

    private let fileManager = FileManager.default

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

            return CleaningResult(
                targetID: target.id,
                strategy: strategy,
                bytesReclaimed: startSize,
                success: true
            )
        } catch {
            return CleaningResult(
                targetID: target.id,
                strategy: strategy,
                bytesReclaimed: 0,
                success: false,
                error: error.localizedDescription
            )
        }
    }

    /// Clean all enabled targets in the given app state.
    func cleanAll(state: AppState) -> [CleaningResult] {
        let targets = state.enabledTargets
        var results: [CleaningResult] = []

        for target in targets {
            let strategy = state.strategyFor(target)
            let result = clean(target: target, strategy: strategy)
            results.append(result)
        }

        return results
    }

    // MARK: - Strategy Implementations

    /// Delete all contents of a directory (or a specific file).
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

        let contents = try fileManager.contentsOfDirectory(atPath: path)
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
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
