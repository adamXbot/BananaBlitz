import Foundation

/// "What would happen if I clicked Blitz Now?" — non-destructive preview.
/// Walks every job, asks the filesystem what it would touch, and reports.
struct DryRunReport: Identifiable {
    let id = UUID()
    let target: PrivacyTarget
    let strategy: CleaningStrategy
    let bytesAtRisk: Int64
    let itemsAtRisk: Int
    let action: String

    var summary: String {
        "\(target.name) — \(action) (\(itemsAtRisk) item\(itemsAtRisk == 1 ? "" : "s"), \(bytesAtRisk.formattedBytes))"
    }
}

enum DryRun {

    /// Action text for a locked target under a non-locking strategy.
    static let lockedSkipAction = "Locked by BananaBlitz — skipped. Use Unlock in Settings → Targets to remove the lock."
    /// Action text for re-applying a lock that is already in place.
    static let alreadyLockedAction = "Already locked — the lock is re-applied, nothing is deleted"

    /// `libraryRoot`, `guardService` and `scanner` are injectable so the plan
    /// can be exercised against a temporary directory in tests.
    static func plan(
        jobs: [CleaningJob],
        libraryRoot: String = PathSafety.defaultLibraryRoot,
        guardService: FileSystemGuard = .shared,
        scanner: TargetScanner = .shared
    ) -> [DryRunReport] {
        let fm = FileManager.default
        let dbExtensions = CleaningStrategy.databaseExtensions

        return jobs.map { job in
            let target = job.target
            let path = target.resolvedPath

            do {
                try PathSafety.validateTargetPath(path, libraryRoot: libraryRoot)
            } catch {
                return DryRunReport(
                    target: target,
                    strategy: job.strategy,
                    bytesAtRisk: 0,
                    itemsAtRisk: 0,
                    action: "Blocked: \(error.localizedDescription)"
                )
            }

            // Mirror the cleaner: a locked target is left alone by every
            // non-locking strategy, and re-locking deletes nothing. Say so,
            // instead of describing a directory that no longer exists.
            if guardService.isLocked(target) {
                return DryRunReport(
                    target: target,
                    strategy: job.strategy,
                    bytesAtRisk: 0,
                    itemsAtRisk: 0,
                    action: job.strategy == .replaceWithFile ? alreadyLockedAction : lockedSkipAction
                )
            }

            switch job.strategy {
            case .replaceWithFile:
                let size = scanner.targetSize(target)
                return DryRunReport(
                    target: target,
                    strategy: job.strategy,
                    bytesAtRisk: size,
                    itemsAtRisk: scanner.fileCount(target),
                    action: "Replace with locked empty file"
                )

            case .wipeContents:
                let size = scanner.targetSize(target)
                let count = target.isSpecificFile
                    ? (fm.fileExists(atPath: path) ? 1 : 0)
                    : scanner.fileCount(target)
                return DryRunReport(
                    target: target,
                    strategy: job.strategy,
                    bytesAtRisk: size,
                    itemsAtRisk: count,
                    action: target.isSpecificFile ? "Delete file" : "Empty directory contents"
                )

            case .deleteDatabases:
                var bytes: Int64 = 0
                var count = 0
                if target.isSpecificFile {
                    let ext = (path as NSString).pathExtension.lowercased()
                    if dbExtensions.contains(ext), fm.fileExists(atPath: path) {
                        if let attrs = try? fm.attributesOfItem(atPath: path),
                           let size = attrs[.size] as? Int64 {
                            bytes = size
                        }
                        count = 1
                    }
                } else if let enumerator = fm.enumerator(
                    at: URL(fileURLWithPath: path, isDirectory: true),
                    includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey],
                    options: [.skipsPackageDescendants]
                ) {
                    for case let fileURL as URL in enumerator {
                        let values = try? fileURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
                        guard values?.isSymbolicLink != true, values?.isRegularFile == true else { continue }

                        let ext = fileURL.pathExtension.lowercased()
                        guard dbExtensions.contains(ext) else { continue }
                        if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                           let size = attrs[.size] as? Int64 {
                            bytes += size
                        }
                        count += 1
                    }
                }
                return DryRunReport(
                    target: target,
                    strategy: job.strategy,
                    bytesAtRisk: bytes,
                    itemsAtRisk: count,
                    action: "Delete database files only"
                )
            }
        }
    }
}
