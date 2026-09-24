import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` so the onboarding schedule step
/// and Settings show the *actual* login-item state, rather than a toggle that
/// can silently disagree with System Settings.
enum LoginItemService {
    enum State: Equatable {
        /// Registered and approved: the app launches at login.
        case enabled
        /// Registered, but macOS is waiting for the user to approve it under
        /// System Settings → General → Login Items.
        case requiresApproval
        /// Not registered, or the bundle is not eligible (e.g. an unsigned
        /// build run straight from Xcode).
        case disabled
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered, .notFound:
            return .disabled
        @unknown default:
            return .disabled
        }
    }

    /// Register or unregister the app as a login item. Throws when macOS
    /// refuses, so callers can leave the toggle where it was and explain.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Open System Settings → General → Login Items.
    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
