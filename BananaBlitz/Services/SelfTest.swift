import Foundation

/// Health-check that walks every privacy target and reports on its reachability.
/// Useful right after install (does FDA actually work?) or after a macOS upgrade
/// where Apple may have moved a path.
enum SelfTest {

    enum Status: String, Codable {
        case ok            // path exists and we could read it
        case missing       // path doesn't exist (could just mean unused)
        case denied        // path exists but we cannot read — usually FDA missing
        case locked        // path exists as our immutable lock file
        case unexpectedFile // path exists as a non-locked plain file (rare)
    }

    struct Report: Identifiable {
        let id = UUID()
        let target: PrivacyTarget
        let status: Status
        let detail: String
    }

    /// Walk every target. Safe to call from a background queue.
    static func run() -> [Report] {
        let fm = FileManager.default
        var reports: [Report] = []

        for target in PrivacyTarget.allTargets {
            let path = target.resolvedPath
            var isDir: ObjCBool = false
            let exists = fm.fileExists(atPath: path, isDirectory: &isDir)

            if !exists {
                reports.append(.init(target: target, status: .missing, detail: "Path not present"))
                continue
            }

            // Specific-file targets: if the path is a regular file, just verify
            // we can read attributes.
            if target.isSpecificFile {
                if FileSystemGuard.shared.isLocked(target) {
                    reports.append(.init(target: target, status: .locked, detail: "Locked by BananaBlitz"))
                } else if (try? fm.attributesOfItem(atPath: path)) != nil {
                    reports.append(.init(target: target, status: .ok, detail: "Readable"))
                } else {
                    reports.append(.init(target: target, status: .denied, detail: "Cannot read attributes — Full Disk Access?"))
                }
                continue
            }

            // Directory targets: check we can list the contents.
            if !isDir.boolValue {
                if FileSystemGuard.shared.isLocked(target) {
                    reports.append(.init(target: target, status: .locked, detail: "Locked by BananaBlitz"))
                } else {
                    reports.append(.init(target: target, status: .unexpectedFile, detail: "Path is a non-locked file"))
                }
                continue
            }

            do {
                _ = try fm.contentsOfDirectory(atPath: path)
                reports.append(.init(target: target, status: .ok, detail: "Readable"))
            } catch let error as NSError {
                if error.domain == NSCocoaErrorDomain &&
                    (error.code == NSFileReadNoPermissionError || error.code == 257) {
                    reports.append(.init(target: target, status: .denied, detail: "Permission denied — Full Disk Access?"))
                } else {
                    reports.append(.init(target: target, status: .denied, detail: error.localizedDescription))
                }
            }
        }

        return reports
    }
}
