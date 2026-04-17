import SwiftUI

/// App entry point — menu-bar-only SwiftUI app with no dock icon.
@main
struct BananaBlitzApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var scheduler = SchedulerService()

    var body: some Scene {
        // Menu bar icon + popover
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(scheduler)
                .onAppear {
                    // Activate app to foreground on first launch so onboarding takes focus
                    if !appState.hasCompletedOnboarding {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }

                    // Wire up the scheduler on first appearance
                    scheduler.configure(with: appState)

                    // If onboarding is done but no targets are set, apply defaults
                    if appState.hasCompletedOnboarding && appState.enabledTargetIDs.isEmpty {
                        appState.setDefaultTargets(for: appState.selectedLevel)
                    }

                    // Perform an initial scan
                    DispatchQueue.global(qos: .utility).async {
                        let results = TargetScanner.shared.scanAll()
                        DispatchQueue.main.async {
                            appState.scanResults = results
                        }
                    }
                }
        } label: {
            HStack(spacing: 3) {
                Text("🍌")
                
                if appState.showMenuBarStatus {
                    Group {
                        if !appState.hasCompletedOnboarding {
                            Image(systemName: "exclamationmark.triangle.fill")
                        } else if appState.isCurrentlyCleaning {
                            Image(systemName: "bolt.fill")
                        } else if appState.isPaused {
                            Image(systemName: "pause.fill")
                        } else if appState.scheduleInterval != .manual {
                            Image(systemName: "clock")
                        }
                    }
                    .font(.system(size: 9, weight: .bold))
                }
            }
        }
        .menuBarExtraStyle(.window)
        .keyboardShortcut(appState.enableKeyboardShortcut ? KeyboardShortcut("b", modifiers: [.command, .control]) : nil)

        // Settings window (opened from menu bar)
        Window("BananaBlitz Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(scheduler)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Onboarding window (opened on first launch)
        Window("Welcome to BananaBlitz", id: "onboarding") {
            OnboardingContainerView()
                .environmentObject(appState)
                .environmentObject(scheduler)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
    }
}
