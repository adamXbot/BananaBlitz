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

    static func plan(jobs: [CleaningJob]) -> [DryRunReport] {
        let fm = FileManager.default
        let dbExtensions: Set<String> = ["db", "sqlite", "sqlite3", "sqlite-shm", "sqlite-wal", "segb"]

        return jobs.map { job in
            let target = job.target
            let path = target.resolvedPath

            switch job.strategy {
            case .replaceWithFile:
                let size = TargetScanner.shared.targetSize(target)
                return DryRunReport(
                    target: target,
                    strategy: job.strategy,
                    bytesAtRisk: size,
                    itemsAtRisk: TargetScanner.shared.fileCount(target),
                    action: "Replace with locked empty file"
                )

            case .wipeContents:
                let size = TargetScanner.shared.targetSize(target)
                let count = target.isSpecificFile
                    ? (fm.fileExists(atPath: path) ? 1 : 0)
                    : TargetScanner.shared.fileCount(target)
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
                } else if let enumerator = fm.enumerator(atPath: path) {
                    while let file = enumerator.nextObject() as? String {
                        let ext = (file as NSString).pathExtension.lowercased()
                        guard dbExtensions.contains(ext) else { continue }
                        let full = (path as NSString).appendingPathComponent(file)
                        if let attrs = try? fm.attributesOfItem(atPath: full),
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
