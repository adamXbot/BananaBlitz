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
            Label("BananaBlitz", systemImage: "shield.checkered")
        }
        .menuBarExtraStyle(.window)

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
