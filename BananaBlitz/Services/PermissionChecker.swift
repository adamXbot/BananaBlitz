import Foundation
import AppKit

/// Checks and manages Full Disk Access permission, which is required
/// for the app to read/write protected ~/Library paths.
class PermissionChecker {
    static let shared = PermissionChecker()

    /// Test if the app has Full Disk Access by attempting to read a protected path.
    func hasFullDiskAccess() -> Bool {
        // These paths are FDA-protected — only accessible with the entitlement
        let testPaths = [
            NSHomeDirectory() + "/Library/Biome",
            NSHomeDirectory() + "/Library/Trial",
            NSHomeDirectory() + "/Library/Suggestions",
            NSHomeDirectory() + "/Library/IntelligencePlatform"
        ]

        for path in testPaths {
            let fm = FileManager.default
            // First check if the path exists
            guard fm.fileExists(atPath: path) else { continue }

            // Try to list the contents — this will fail without FDA
            do {
                _ = try fm.contentsOfDirectory(atPath: path)
                return true  // Success: we have FDA
            } catch let error as NSError {
                if error.domain == NSCocoaErrorDomain &&
                   (error.code == NSFileReadNoPermissionError || error.code == 257) {
                    return false  // Explicitly denied
                }
                // Other errors (empty dir, etc.) — try next path
                continue
            }
        }

        // If no test paths exist, assume we have access
        // (unlikely edge case on a fresh macOS install)
        return true
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
}
