import Foundation
import AppKit
import Darwin

/// Checks and manages Full Disk Access permission, which is required
/// for the app to read/write protected ~/Library paths.
class PermissionChecker {
    static let shared = PermissionChecker()

    /// Test if the app has Full Disk Access by attempting to read a protected path.
    func hasFullDiskAccess() -> Bool {
        let home = NSHomeDirectory()
        let probes: [Probe] = [
            .file(home + "/Library/Application Support/com.apple.TCC/TCC.db"),
            .directory(home + "/Library/Biome"),
            .directory(home + "/Library/Trial"),
            .directory(home + "/Library/Suggestions"),
            .directory(home + "/Library/IntelligencePlatform")
        ]

        for probe in probes {
            guard FileManager.default.fileExists(atPath: probe.path) else { continue }

            do {
                try verifyReadable(probe)
                return true
            } catch let error as NSError {
                if isPermissionDenied(error) {
                    return false
                }

                continue
            }
        }

        // Conservative fallback: if none of the protected probes exist, don't
        // claim FDA until we can positively read one.
        return false
    }

    /// Open System Settings → Privacy & Security → Full Disk Access.
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open System Settings → Privacy & Security → Automation.
    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    private enum Probe {
        case file(String)
        case directory(String)

        var path: String {
            switch self {
            case .file(let path), .directory(let path): return path
            }
        }
    }

    private func verifyReadable(_ probe: Probe) throws {
        switch probe {
        case .file(let path):
            let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
            try handle.close()
        case .directory(let path):
            _ = try FileManager.default.contentsOfDirectory(atPath: path)
        }
    }

    private func isPermissionDenied(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain {
            return error.code == NSFileReadNoPermissionError || error.code == 257
        }

        if error.domain == NSPOSIXErrorDomain {
            return error.code == EACCES || error.code == EPERM
        }

        return false
    }
}
