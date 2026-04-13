import Foundation

/// Scans privacy targets on disk to determine their existence, size, and lock status.
class TargetScanner {
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
    func isLocked(_ target: PrivacyTarget) -> Bool {
        FileSystemGuard.shared.isLocked(target)
    }

    /// Count the number of files inside a target directory.
    func fileCount(_ target: PrivacyTarget) -> Int {
        let path = target.resolvedPath
        guard !target.isSpecificFile else { return fileManager.fileExists(atPath: path) ? 1 : 0 }
        guard let enumerator = fileManager.enumerator(atPath: path) else { return 0 }

        var count = 0
        while let _ = enumerator.nextObject() as? String {
            count += 1
        }
        return count
    }

    // MARK: - Helpers

    /// Recursively calculate the size of a directory.
    private func directorySize(path: String) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            // If it's a file (possibly a lock file), return its size
            if let attrs = try? fileManager.attributesOfItem(atPath: path) {
                return (attrs[.size] as? Int64) ?? 0
            }
            return 0
        }

        guard let enumerator = fileManager.enumerator(atPath: path) else { return 0 }

        var totalSize: Int64 = 0
        while let file = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(file)
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
               let size = attrs[.size] as? Int64 {
                totalSize += size
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
