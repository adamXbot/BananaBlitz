import Foundation

/// Handles the aggressive "replace with immutable file" strategy.
/// Replaces a directory with an empty file and sets the `uchg` (user immutable) flag
/// so the corresponding daemon cannot recreate its data store.
///
/// Since all targets are in ~/Library (user-owned), no sudo is required.
class FileSystemGuard {
    static let shared = FileSystemGuard()

    private let fileManager = FileManager.default

    // MARK: - Lock / Unlock

    /// Replace a target directory with an immutable empty file.
    func lockTarget(_ target: PrivacyTarget) throws {
        let path = target.resolvedPath

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
        let path = target.resolvedPath

        if fileManager.fileExists(atPath: path) {
            // Remove immutable flag
            try setImmutableFlag(at: path, immutable: false)
            // Remove the lock file
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
    func isLocked(_ target: PrivacyTarget) -> Bool {
        let path = target.resolvedPath
        var isDir: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
            return false
        }

        // A directory target is "locked" if the path exists as a file (not directory)
        if !target.isSpecificFile && !isDir.boolValue {
            return true
        }

        // For specific files, check the NSFileImmutable attribute
        if target.isSpecificFile {
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let isImmutable = attrs[.immutable] as? Bool {
                return isImmutable
            }
        }

        return false
    }

    // MARK: - chflags

    /// Set or remove the user immutable flag using `/usr/bin/chflags`.
    private func setImmutableFlag(at path: String, immutable: Bool) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        process.arguments = [immutable ? "uchg" : "nouchg", path]

        let errorPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw BananaBlitzError.chflagsFailed(path, errorMessage)
        }
    }
}

// MARK: - Errors

enum BananaBlitzError: LocalizedError {
    case failedToCreateLockFile(String)
    case chflagsFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .failedToCreateLockFile(let path):
            return "Failed to create lock file at \(path)"
        case .chflagsFailed(let path, let detail):
            return "chflags failed on \(path): \(detail)"
        }
    }
}
