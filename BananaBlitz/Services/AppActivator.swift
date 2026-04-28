import AppKit

/// Manages NSApp's activation policy so user-facing windows are properly
/// findable in Cmd-Tab while the menu bar app is otherwise dormant in
/// `.accessory` mode.
///
/// The flow:
///   1. The Info.plist sets `LSUIElement = true`, so the app launches as a
///      menu bar agent: no Dock icon, no Cmd-Tab presence, and any window
///      opened via `openWindow(id:)` won't reliably come to the front
///      because the app isn't a "real" foreground app.
///   2. When the user opens Settings / Onboarding / About, call
///      `bringWindowForward(titled:)`. The activator switches to `.regular`,
///      activates the app, and orders the matching `NSWindow` to the front.
///   3. The activator listens for `NSWindow.willCloseNotification`. When the
///      last tracked window closes, it returns the app to `.accessory` so
///      the Dock icon vanishes and agent-style behaviour is restored.
@MainActor
final class AppActivator: ObservableObject {
    static let shared = AppActivator()

    /// Titles of every "real" window the app exposes. A window must match
    /// exactly the title used in the corresponding `Window(...)` scene
    /// definition.
    private static let trackedWindowTitles: Set<String> = [
        "Welcome to BananaBlitz",
        "BananaBlitz Settings",
        "About BananaBlitz"
    ]

    private var observer: NSObjectProtocol?
    private let log = AppLog.app

    /// Window titles that have been requested but whose NSWindow may not have
    /// materialised yet. Prevents `checkAndRestorePolicy` from reverting to
    /// `.accessory` in the gap between requesting a new window and SwiftUI
    /// actually creating it (e.g. Settings dismissed while Onboarding opens
    /// from `Reset All Settings`).
    private var pendingWindowTitles: Set<String> = []

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Defer the visibility check by a runloop tick so the closing
            // window has actually been removed from `NSApp.windows`.
            DispatchQueue.main.async {
                self?.checkAndRestorePolicy()
            }
        }
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Bring forward

    /// Bring the named window to the front. Switches the app to `.regular`
    /// (so it appears in Cmd-Tab and the Dock), activates the app, and
    /// orders the matching NSWindow to the front and makes it key.
    ///
    /// Caller pattern:
    ///
    ///     openWindow(id: "settings")
    ///     AppActivator.shared.bringWindowForward(titled: "BananaBlitz Settings")
    func bringWindowForward(titled title: String) {
        log.debug("bringWindowForward title=\(title, privacy: .public)")
        pendingWindowTitles.insert(title)
        NSApp.setActivationPolicy(.regular)
        // Defer slightly so SwiftUI has had a chance to instantiate the window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            // Re-assert .regular in case a willClose handler reverted us in the
            // gap (e.g. Settings → Onboarding via Reset All Settings).
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.title == title }) {
                window.makeKeyAndOrderFront(nil)
                self?.pendingWindowTitles.remove(title)
            } else {
                self?.log.debug("No window titled \(title, privacy: .public) yet; retrying")
                // Final retry after another tick — SwiftUI sometimes constructs
                // the window late.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if let window = NSApp.windows.first(where: { $0.title == title }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                    self?.pendingWindowTitles.remove(title)
                }
            }
        }
    }

    // MARK: - Restore agent mode

    /// Re-check whether any tracked window is still visible. If none are,
    /// return to `.accessory` so the Dock icon goes away.
    private func checkAndRestorePolicy() {
        let anyOpen = NSApp.windows.contains { window in
            window.isVisible && Self.trackedWindowTitles.contains(window.title)
        }
        if !anyOpen && pendingWindowTitles.isEmpty {
            log.debug("All tracked windows closed; reverting to .accessory")
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
