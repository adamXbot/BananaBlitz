import Foundation

/// A pre-computed snapshot of every target's size + lock state.
/// View code reads from `AppState.scanResults` / `AppState.lockStates`,
/// which are populated from this in one publish.
struct ScanSummary {
    var sizes: [String: Int64]
    var lockStates: [String: Bool]

    static let empty = ScanSummary(sizes: [:], lockStates: [:])
}

/// Scans privacy targets on disk to determine their existence, size, and lock status.
final class TargetScanner {
    static let shared = TargetScanner()

    private let fileManager = FileManager.default

    // MARK: - Scanning

    /// Scan all targets and return a dictionary of targetID → size in bytes.
    func scanAll() -> [String: Int64] {
        var results: [String: Int64] = [:]
        for target in PrivacyTarget.allTargets {
            results[target.id] = targetSize(target)
        }
        return results
    }

    /// Scan all targets and return both sizes and lock states. Run off-main.
    func summariseAll() -> ScanSummary {
        var sizes: [String: Int64] = [:]
        var locks: [String: Bool] = [:]
        for target in PrivacyTarget.allTargets {
            sizes[target.id] = targetSize(target)
            locks[target.id] = FileSystemGuard.shared.isLocked(target)
        }
        return ScanSummary(sizes: sizes, lockStates: locks)
    }

    /// Scan targets in a specific level.
    func scan(level: CleaningLevel) -> [String: Int64] {
        var results: [String: Int64] = [:]
        for target in PrivacyTarget.targets(for: level) {
            results[target.id] = targetSize(target)
        }
        return results
    }

    // MARK: - Individual Target Info

    /// Calculate the total size of a target on disk.
    func targetSize(_ target: PrivacyTarget) -> Int64 {
        let path = target.resolvedPath

        if target.isSpecificFile {
            guard let attrs = try? fileManager.attributesOfItem(atPath: path) else { return 0 }
            return (attrs[.size] as? Int64) ?? 0
        }

        return directorySize(path: path)
    }

    /// Check if a target path exists on disk.
    func targetExists(_ target: PrivacyTarget) -> Bool {
        fileManager.fileExists(atPath: target.resolvedPath)
    }

    /// Check if a target is currently locked (replaced with immutable file).
    /// Hits the filesystem — prefer `AppState.lockStates[target.id]` from view code.
    func isLocked(_ target: PrivacyTarget) -> Bool {
        FileSystemGuard.shared.isLocked(target)
    }

    /// Count the number of files inside a target directory.
    func fileCount(_ target: PrivacyTarget) -> Int {
        let path = target.resolvedPath
        guard !target.isSpecificFile else { return fileManager.fileExists(atPath: path) ? 1 : 0 }
        guard let enumerator = fileManager.enumerator(atPath: path) else { return 0 }

        var count = 0
        while enumerator.nextObject() != nil {
            count += 1
        }
        return count
    }

    // MARK: - Helpers

    /// Recursively calculate the size of a directory.
    /// Skips symbolic links to avoid following them out of the target tree.
    private func directorySize(path: String) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            // If it's a file (possibly a lock file), return its size.
            if let attrs = try? fileManager.attributesOfItem(atPath: path) {
                return (attrs[.size] as? Int64) ?? 0
            }
            return 0
        }

        let url = URL(fileURLWithPath: path)
        let keys: [URLResourceKey] = [.fileSizeKey, .isSymbolicLinkKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: Set(keys))
                if values.isSymbolicLink == true { continue }
                if let size = values.fileSize { totalSize += Int64(size) }
            } catch {
                continue
            }
        }
        return totalSize
    }
}

// MARK: - Formatting Helpers

extension Int64 {
    /// Format bytes into a human-readable string (e.g. "142 MB").
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
