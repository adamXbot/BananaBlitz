import SwiftUI
import AppKit

/// App entry point — a menu bar utility with no Dock icon while idle. The
/// Settings window, About, the main menu, Help and the popover chrome come
/// from the shared surface code in `Shared/MacSurfaces`.
@main
struct BananaBlitzApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var scheduler = SchedulerService()
    @StateObject private var menuBar = SurfaceMenuBarPreference(defaultIcon: MenuBarIconStyle.default.rawValue)
    @StateObject private var updates: SurfaceUpdates
    @Environment(\.openWindow) private var openWindow

    /// Owns Sparkle's controller for the life of the app.
    private let updater: UpdaterService
    private let app = SurfaceApp.bananaBlitz

    init() {
        // Older builds stored the menu bar icon under their own key; move it
        // before the preference object reads the shared one.
        MenuBarIconStyle.migrateLegacyPreference()
        // Dock icon only while a window is open; menu bar only otherwise.
        SurfaceActivation.shared.start()

        let updater = UpdaterService()
        self.updater = updater
        _updates = StateObject(wrappedValue: SurfaceUpdates(
            driver: updater.updater,
            releaseNotes: BananaBlitzSurface.releaseNotes
        ))
    }

    /// The shared manual and shortcut windows open by default; only the
    /// welcome needs app code, because the setup wizard is the app's own.
    private var help: SurfaceHelp {
        SurfaceHelp(replayWelcome: {
            NSApplication.shared.activate()
            openWindow(id: "onboarding")
        })
    }

    var body: some Scene {
        // Menu bar icon + popover
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(scheduler)
                .onAppear(perform: bootstrap)
        } label: {
            // Extracted into its own View so it can host `@Environment(\.openWindow)`
            // and react via `.onAppear` at app launch (the label is rendered as
            // soon as the menu bar item appears).
            MenuBarLabel(appState: appState, menuBar: menuBar)
        }
        .menuBarExtraStyle(.window)
        .keyboardShortcut(appState.enableKeyboardShortcut ? KeyboardShortcut("b", modifiers: [.command, .control]) : nil)
        .commands {
            SurfaceCommands(app: app, help: help, updates: updates)
            BananaBlitzCommands(appState: appState)
        }

        Settings {
            SurfaceSettings(app: app, panes: panes)
                .environmentObject(appState)
                .environmentObject(scheduler)
        }

        SurfaceAboutWindow(app: app, help: help)

        SurfaceManualWindow(app: app)

        SurfaceShortcutsWindow(groups: [
            .standard(for: app),
            SurfaceShortcutGroup("Menu bar item", items: [
                SurfaceShortcut("⌘⌃B", "Open the menu bar item",
                                detail: "When the global shortcut is on in Settings ▸ General"),
                SurfaceShortcut("⌘↩", "Blitz Now", detail: "While the menu bar item is open"),
            ]),
        ])

        // Setup wizard. Title bar kept so the window is easy to find in the
        // window switcher; `Welcome to BananaBlitz` in Help replays it.
        Window("Welcome to BananaBlitz", id: "onboarding") {
            OnboardingContainerView()
                .environmentObject(appState)
                .environmentObject(scheduler)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    /// General first, Updates last; five tabs in all.
    private var panes: [SurfacePane] {
        [
            SurfacePane("General", systemImage: "gearshape") {
                GeneralPane(menuBar: menuBar)
            },
            SurfacePane("Targets", systemImage: "target") {
                TargetListView()
            },
            SurfacePane("Schedule", systemImage: "clock") {
                SchedulePane()
            },
            SurfacePane("Data", systemImage: "internaldrive") {
                DataPane()
            },
            .updates(updates),
        ]
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

// MARK: - File menu

/// The app's own export verbs, in File where the standard puts them. The
/// app menu and Help come from `SurfaceCommands`.
private struct BananaBlitzCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Save Recovery Script…") {
                _ = ExportActions.saveRecoveryScript()
            }
            Button("Export Cleaning History…") {
                _ = ExportActions.exportHistory(appState.cleaningHistory)
            }
        }
    }
}

// MARK: - MenuBarExtra label

/// The banana + status badge shown in the menu bar.
///
/// Extracted as its own View so it can use `@Environment(\.openWindow)` and
/// run an `.onAppear` block at app launch — the label is rendered as soon
/// as the menu bar item appears, which happens before any user interaction.
/// We use that hook to auto-open onboarding when the user hasn't completed
/// it, so users don't have to hunt for the menu bar icon on first launch.
private struct MenuBarLabel: View {
    @ObservedObject var appState: AppState
    @ObservedObject var menuBar: SurfaceMenuBarPreference
    @Environment(\.openWindow) private var openWindow

    /// Guard against re-firing if SwiftUI rebuilds the label.
    @State private var hasAutoOpened = false

    private var style: MenuBarIconStyle {
        MenuBarIconStyle(rawValue: menuBar.icon) ?? .default
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MenuBarIconGlyph(style: style)

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
                NSApplication.shared.activate()
                openWindow(id: "onboarding")
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
                         label: "Setup incomplete")
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

    /// The glyph changes with state, and its accessibility label says the
    /// state in words.
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
