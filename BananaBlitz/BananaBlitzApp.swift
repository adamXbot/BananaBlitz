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

    /// Guard against re-firing if SwiftUI rebuilds the label.
    @State private var hasAutoOpened = false

    var body: some View {
        HStack(spacing: 3) {
            Text("🍌")

            if appState.showMenuBarStatus {
                Group {
                    if !appState.hasCompletedOnboarding {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .accessibilityLabel("Onboarding incomplete")
                    } else if appState.isCurrentlyCleaning {
                        Image(systemName: "bolt.fill")
                            .accessibilityLabel("Cleaning")
                    } else if appState.isPaused {
                        Image(systemName: "pause.fill")
                            .accessibilityLabel("Schedule paused")
                    } else if appState.scheduleInterval != .manual {
                        Image(systemName: "clock")
                            .accessibilityLabel("Schedule active")
                    }
                }
                .font(.system(size: 9, weight: .bold))
            }
        }
        .accessibilityLabel("BananaBlitz")
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
}
