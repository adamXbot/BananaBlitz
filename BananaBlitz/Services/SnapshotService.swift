import Foundation
import AppKit

/// Service for managing APFS snapshots using tmutil.
class SnapshotService {
    static let shared = SnapshotService()
    
    /// Result of a snapshot operation.
    enum SnapshotResult {
        case success
        case failure(String)
        case cancelled
    }
    
    /// Creates a local APFS snapshot of the boot volume.
    /// Note: This requires administrator privileges and will trigger a system prompt.
    func createSnapshot(completion: @escaping (SnapshotResult) -> Void) {
        // Execute the command via AppleScript to handle the password/TouchID prompt natively.
        let command = "do shell script \"/usr/bin/tmutil localsnapshot /\" with administrator privileges"
        
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: command) {
                _ = script.executeAndReturnError(&error)
                
                DispatchQueue.main.async {
                    if let error = error {
                        let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                        // AppleScript error -128 is "User cancelled"
                        if error[NSAppleScript.errorNumber] as? Int == -128 {
                            completion(.cancelled)
                        } else {
                            completion(.failure(errorMessage))
                        }
                    } else {
                        completion(.success)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure("Failed to initialize AppleScript engine."))
                }
            }
        }
    }
}
