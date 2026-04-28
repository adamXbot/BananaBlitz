import Foundation

/// Service for managing APFS local snapshots via `tmutil`.
///
/// `tmutil localsnapshot /` does **not** require administrator privileges on
/// modern macOS — the previous AppleScript `with administrator privileges`
/// elevation has been removed so the user no longer sees a sudo / Touch ID
/// prompt for an operation that is fundamentally a user-level Time Machine
/// snapshot.
///
/// Note: a `tmutil localsnapshot` produces a Time Machine local snapshot —
/// useful for restoring individual files, not a one-click bootable rollback.
/// UI copy should be worded accordingly.
final class SnapshotService {
    static let shared = SnapshotService()

    enum SnapshotResult {
        case success
        case failure(String)
        case cancelled
    }

    private let log = AppLog.snapshot

    /// Creates a local APFS snapshot of the boot volume by invoking
    /// `/usr/bin/tmutil localsnapshot /`.
    func createSnapshot(completion: @escaping (SnapshotResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.runTmutilLocalSnapshot() ?? .failure("Service unavailable")
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func runTmutilLocalSnapshot() -> SnapshotResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["localsnapshot", "/"]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            log.error("Failed to launch tmutil: \(error.localizedDescription, privacy: .public)")
            return .failure("Failed to launch tmutil: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return .success
        }

        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let detail = errorMessage.isEmpty
            ? "tmutil exited with status \(process.terminationStatus)"
            : errorMessage

        log.error("tmutil localsnapshot failed: \(detail, privacy: .public)")
        return .failure(detail)
    }
}
