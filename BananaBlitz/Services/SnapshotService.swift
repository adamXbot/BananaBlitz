import Foundation

/// Service for managing APFS local snapshots via `tmutil`.
///
/// `tmutil localsnapshot` does **not** require administrator privileges on
/// modern macOS, nor a configured Time Machine destination (verified on
/// macOS 27 with none configured). The previous AppleScript
/// `with administrator privileges` elevation has been removed so the user no
/// longer sees a sudo / Touch ID prompt for an operation that is
/// fundamentally a user-level Time Machine snapshot.
///
/// Note: a `tmutil localsnapshot` produces a Time Machine local snapshot —
/// useful for restoring individual files, not a one-click bootable rollback.
/// UI copy should be worded accordingly.
final class SnapshotService {
    static let shared = SnapshotService()

    enum SnapshotResult {
        /// `snapshotName` is tmutil's snapshot date (e.g. `2026-09-24-124007`)
        /// when it could be parsed from the output, so the UI can name what
        /// was created.
        case success(snapshotName: String?)
        case failure(String)
    }

    private let log = AppLog.snapshot

    /// Creates a local APFS snapshot by invoking `/usr/bin/tmutil localsnapshot`.
    func createSnapshot(completion: @escaping (SnapshotResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.runTmutilLocalSnapshot() ?? .failure("Service unavailable")
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// Extract the snapshot date from tmutil's
    /// `Created local snapshot with date: 2026-09-24-124007` line.
    static func snapshotName(in output: String) -> String? {
        let marker = "Created local snapshot with date:"
        for line in output.split(whereSeparator: \.isNewline) {
            guard let range = line.range(of: marker) else { continue }
            let name = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name
        }
        return nil
    }

    private func runTmutilLocalSnapshot() -> SnapshotResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        // `localsnapshot` takes no arguments (see `tmutil` usage). It snapshots
        // every APFS volume Time Machine covers, which includes the boot
        // volume even when no backup destination is configured.
        process.arguments = ["localsnapshot"]

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

        // Drain both pipes before waiting so tmutil can never block on a full pipe.
        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let name = Self.snapshotName(in: output + "\n" + errorOutput)
            log.info("tmutil localsnapshot succeeded: \(name ?? "date not reported", privacy: .public)")
            return .success(snapshotName: name)
        }

        let detail = [errorOutput, output]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
            ?? "tmutil exited with status \(process.terminationStatus)"

        log.error("tmutil localsnapshot failed: \(detail, privacy: .public)")
        return .failure(detail)
    }
}
