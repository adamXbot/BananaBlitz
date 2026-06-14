import SwiftUI
import AppKit

/// App entry point — menu-bar-only SwiftUI app with no dock icon.
@main
struct BananaBlitzApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var scheduler = SchedulerService()
    @StateObject private var updater = UpdaterService()

    var body: some Scene {
        // Menu bar icon + popover
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(scheduler)
                .environmentObject(updater)
                .onAppear(perform: bootstrap)
        } label: {
            // Extracted into its own View so it can host `@Environment(\.openWindow)`
            // and react via `.onAppear` at app launch (the label is rendered as
            // soon as the menu bar item appears).
            MenuBarLabel(appState: appState)
        }
        .menuBarExtraStyle(.window)
        .keyboardShortcut(appState.enableKeyboardShortcut ? KeyboardShortcut("b", modifiers: [.command, .control]) : nil)

        // Settings window (opened from menu bar)
        Window("BananaBlitz Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(scheduler)
                .environmentObject(updater)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        // Adds "Settings…" and "Check for Updates…" to the BananaBlitz
        // application menu in the macOS menu bar. The menu is only visible
        // while the app is `.regular` — i.e. while Settings / Onboarding /
        // About is open. Both actions remain reachable from the menu bar
        // popover (Settings) and the Settings → Updates section (manual
        // update check) when no window is open.
        .commands {
            AppCommands(updater: updater)
        }

        // Onboarding window. Title bar restored — `.hiddenTitleBar` made the
        // window hard to identify in the window switcher and impossible to
        // grab without random-clicking, which compounded the activation-policy
        // issue described in `AppActivator`.
        Window("Welcome to BananaBlitz", id: "onboarding") {
            OnboardingContainerView()
                .environmentObject(appState)
                .environmentObject(scheduler)
                .environmentObject(updater)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // About window
        Window("About BananaBlitz", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    /// Run once when the menu bar item first appears: wire the scheduler
    /// (which now also runs catch-up cleans for any missed fires), apply
    /// default targets, and seed the scan + lock-state caches.
    private func bootstrap() {
        scheduler.configure(with: appState)

        if appState.hasCompletedOnboarding && appState.enabledTargetIDs.isEmpty {
            appState.setDefaultTargets(for: appState.selectedLevel)
        }

        // Seed scanResults + lockStates for view code.
        DispatchQueue.global(qos: .utility).async {
            let summary = TargetScanner.shared.summariseAll()
            DispatchQueue.main.async {
                appState.applyScanSummary(summary)
                appState.fullDiskAccessGranted = PermissionChecker.shared.hasFullDiskAccess()
            }
        }
    }
}

// MARK: - Application Menu Commands

/// Adds "Settings…" and "Check for Updates…" entries to the BananaBlitz
/// application menu (the macOS top-of-screen menu, the one whose title is
/// the app name). They appear just under "About BananaBlitz" — the
/// conventional spot — and are reachable while any user-facing window
/// is open (which is when the app is `.regular` per AppActivator).
private struct AppCommands: Commands {
    @ObservedObject var updater: UpdaterService
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Divider()

            Button("Settings…") {
                openWindow(id: "settings")
                AppActivator.shared.bringWindowForward(titled: "BananaBlitz Settings")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Check for Updates…") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)
        }
    }
}

// MARK: - MenuBarExtra label

/// The 🍌 + status-icon shown in the menu bar.
///
/// Extracted as its own View so it can use `@Environment(\.openWindow)` and
/// run an `.onAppear` block at app launch — the label is rendered as soon
/// as the menu bar item appears, which happens before any user interaction.
/// We use that hook to auto-open onboarding when the user hasn't completed
/// it, so users don't have to hunt for the menu bar icon on first launch.
private struct MenuBarLabel: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    /// Observed directly (rather than via `appState`) so the menu bar glyph
    /// swaps the instant the Settings picker writes a new value: `@AppStorage`
    /// inside an `ObservableObject` doesn't reliably republish, but `@AppStorage`
    /// in a `View` reacts to the underlying `UserDefaults` key changing.
    @AppStorage(StorageKey.menuBarIconStyleRaw) private var menuBarIconStyleRaw = MenuBarIconStyle.bananaMono.rawValue

    /// Guard against re-firing if SwiftUI rebuilds the label.
    @State private var hasAutoOpened = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MenuBarIconGlyph(style: MenuBarIconStyle(rawValue: menuBarIconStyleRaw) ?? .bananaMono)

            if appState.showMenuBarStatus, let badge = currentBadge {
                statusBadge(badge)
                    // Pin to the top-right corner of the banana so the
                    // overall label still sizes to the banana's bounding
                    // box. The offset nudges the badge so it overlaps the
                    // banana's edge like a notification dot rather than
                    // floating in empty space.
                    .offset(x: 5, y: -3)
            }
        }
        .accessibilityLabel(accessibilityDescription)
        .onAppear {
            guard !hasAutoOpened, !appState.hasCompletedOnboarding else { return }
            hasAutoOpened = true
            // Defer one runloop tick so the SwiftUI scene graph is fully
            // constructed before we ask it to open another window.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                openWindow(id: "onboarding")
                AppActivator.shared.bringWindowForward(titled: "Welcome to BananaBlitz")
            }
        }
    }

    // MARK: - Status badge

    /// One status indicator overlaid on the banana, prioritised most-urgent
    /// first. Returns `nil` for the steady-state idle case so the menu bar
    /// stays visually quiet when nothing needs attention.
    private var currentBadge: StatusBadge? {
        if !appState.hasCompletedOnboarding {
            return .init(symbol: "exclamationmark", color: .orange,
                         label: "Onboarding incomplete")
        }
        if appState.isCurrentlyCleaning {
            return .init(symbol: "bolt.fill", color: .blue,
                         label: "Cleaning")
        }
        if appState.isPaused {
            return .init(symbol: "pause.fill", color: .gray,
                         label: "Schedule paused")
        }
        if appState.scheduleInterval != .manual {
            // Active-but-idle: a small green dot, no inner glyph. Subtle
            // enough not to compete with the banana but tells you the
            // scheduler is armed.
            return .init(symbol: nil, color: .green,
                         label: "Schedule active")
        }
        return nil
    }

    @ViewBuilder
    private func statusBadge(_ badge: StatusBadge) -> some View {
        ZStack {
            Circle()
                .fill(badge.color)
                .frame(width: 10, height: 10)
                // Thin border that picks up the system menu bar's
                // background colour so the badge separates cleanly from
                // the banana's edge in both light and dark menu bars.
                .overlay(
                    Circle()
                        .strokeBorder(Color(NSColor.windowBackgroundColor), lineWidth: 1)
                )
            if let symbol = badge.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 6, weight: .black))
                    .foregroundStyle(.white)
            }
        }
    }

    private var accessibilityDescription: String {
        if let badge = currentBadge {
            return "BananaBlitz — \(badge.label)"
        }
        return "BananaBlitz"
    }
}

/// One overlaid notifier badge. `symbol == nil` renders an indicator dot
/// without an inner glyph (used for the steady "schedule active" state).
private struct StatusBadge {
    let symbol: String?
    let color: Color
    let label: String
}

// MARK: - Menu bar icon glyph

/// Renders the user's chosen base menu bar glyph (without the status badge),
/// shared by the menu bar label and the Settings picker preview so both stay
/// in sync. The mono banana and the SF Symbol are template images, so the
/// system tints them to match the menu bar; the colour banana stays yellow.
struct MenuBarIconGlyph: View {
    let style: MenuBarIconStyle

    var body: some View {
        switch style {
        case .banana:
            Text("🍌")
        case .bananaMono:
            Image(nsImage: Self.monoBananaTemplate)
        case .sparkles:
            Image(systemName: "sparkles")
        }
    }

    /// A monochrome banana drawn as a hollow (outline) *template* `NSImage`, so
    /// a status item tints it black-in-light / white-in-dark and inverts it
    /// while the menu is open — exactly how an SF Symbol behaves — with no asset
    /// to ship. Built once and reused; status items copy it as needed.
    static let monoBananaTemplate: NSImage = {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            // Authored in a 24×24 design space (origin top-left), sized to fill
            // the box with a small margin so the outline reads at menu-bar size,
            // then scaled to the image. The two on-curve points near (20,20)
            // form the rounded lower tip; the path closes at the upper tip.
            let s = side / 24.0
            func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: y * s) }

            let banana = NSBezierPath()
            banana.move(to: p(4.5, 2.9))
            banana.curve(to: p(20.4, 20.0), controlPoint1: p(3.5, 13.5), controlPoint2: p(10.6, 20.8))
            banana.curve(to: p(19.1, 18.2), controlPoint1: p(20.6, 19.1), controlPoint2: p(20.2, 18.4))
            banana.curve(to: p(6.6, 3.9),   controlPoint1: p(11.4, 16.6), controlPoint2: p(6.5, 10.9))
            banana.curve(to: p(4.5, 2.9),   controlPoint1: p(6.5, 2.9),   controlPoint2: p(5.4, 2.2))
            banana.close()

            banana.lineWidth = 1.6
            banana.lineJoinStyle = .round
            banana.lineCapStyle = .round
            NSColor.black.setStroke()
            banana.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
