import SwiftUI
import ServiceManagement
import AppKit

/// Settings window with tabs for Schedule, Targets, and Preferences.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scheduler: SchedulerService
    @EnvironmentObject var updater: UpdaterService
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var unbrickStatusMessage: String?
    @State private var dryRunReports: [DryRunReport] = []
    @State private var dryRunSheetPresented = false
    @State private var selfTestReports: [SelfTest.Report] = []
    @State private var selfTestSheetPresented = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("🍌")
                    .font(.title2)
                Text("BananaBlitz Settings")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding()

            // Tab bar
            HStack(spacing: 0) {
                tabButton("Dashboard", icon: "chart.bar.fill", index: 0)
                tabButton("Targets", icon: "target", index: 1)
                tabButton("Schedule", icon: "clock.fill", index: 2)
                tabButton("Preferences", icon: "gear", index: 3)
            }
            .padding(.horizontal)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case 0: dashboardTab
                case 1: targetsTab
                case 2: scheduleTab
                case 3: preferencesTab
                default: dashboardTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 620, height: 520)
        .task {
            // Refresh FDA status periodically while Settings is open.
            await pollFullDiskAccess()
        }
    }

    // MARK: - Tab Button

    private func tabButton(_ title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 10, weight: selectedTab == index ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(selectedTab == index ? .primary : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == index ? Color.accentColor.opacity(0.1) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dashboard Tab

    private var dashboardTab: some View {
        ScrollView {
            DashboardView()
                .environmentObject(appState)
                .padding()
        }
    }

    // MARK: - Targets Tab

    private var targetsTab: some View {
        TargetListView()
            .environmentObject(appState)
    }

    // MARK: - Schedule Tab

    private var scheduleTab: some View {
        Form {
            Section("Cleaning Schedule") {
                Picker("Interval", selection: Binding(
                    get: { appState.scheduleInterval },
                    set: {
                        appState.scheduleInterval = $0
                        scheduler.updateSchedule()
                    }
                )) {
                    ForEach(ScheduleInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Pause Schedule", isOn: Binding(
                    get: { appState.isPaused },
                    set: {
                        appState.isPaused = $0
                        scheduler.updateSchedule()
                    }
                ))

                if scheduler.isActive, let timeLeft = scheduler.timeUntilNextClean {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Next clean \(timeLeft)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Cleaning Level") {
                Picker("Default Level", selection: Binding(
                    get: { appState.selectedLevel },
                    set: {
                        appState.selectedLevel = $0
                        appState.setDefaultTargets(for: $0)
                    }
                )) {
                    ForEach(CleaningLevel.allCases) { level in
                        HStack {
                            Text(level.emoji)
                            Text(level.displayName)
                        }
                        .tag(level)
                    }
                }
                .pickerStyle(.menu)

                Text(appState.selectedLevel.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Global Default Strategy"), footer: Text("Changing this will apply the strategy to all enabled targets that support it. You can still finely tune specific strategies per-target under the Targets tab.")) {
                Picker("Strategy Override", selection: Binding(
                    get: { appState.globalStrategy },
                    set: { appState.globalStrategy = $0 }
                )) {
                    ForEach(CleaningStrategy.allCases) { strategy in
                        HStack {
                            Image(systemName: strategy.icon)
                            Text(strategy.displayName)
                        }
                        .tag(strategy)
                    }
                }
                .pickerStyle(.menu)

                // Show explanations for the global strategies
                VStack(spacing: 8) {
                    ForEach(CleaningStrategy.allCases) { strategy in
                        HStack(spacing: 12) {
                            Image(systemName: strategy.icon)
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(strategy.displayName)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(strategy.description)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 4)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Preferences Tab

    private var preferencesTab: some View {
        Form {
            Section("Notifications") {
                Picker("After Auto-Clean", selection: Binding(
                    get: { appState.notificationStyle },
                    set: { appState.notificationStyle = $0 }
                )) {
                    ForEach(NotificationStyle.allCases) { style in
                        HStack {
                            Image(systemName: style.icon)
                            Text(style.displayName)
                        }
                        .tag(style)
                    }
                }
            }

            Section(header: Text("Updates"), footer: updatesFooter) {
                Toggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
                    .disabled(!updater.canCheckForUpdates)

                if updater.automaticallyChecksForUpdates {
                    Picker("Check frequency", selection: $updater.updateCheckInterval) {
                        Text("Daily").tag(86400.0)
                        Text("Weekly").tag(86400.0 * 7)
                        Text("Monthly").tag(86400.0 * 30)
                    }
                    .pickerStyle(.menu)
                    .disabled(!updater.canCheckForUpdates)
                }

                HStack {
                    Button("Check Now") {
                        updater.checkForUpdates()
                    }
                    .disabled(!updater.canCheckForUpdates)

                    Spacer()

                    if let last = updater.lastUpdateCheckDate {
                        Text("Last checked \(last, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Preferences") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { newValue in
                        appState.launchAtLogin = newValue
                        updateLoginItem(enabled: newValue)
                    }
                ))

                Toggle("Show Menu Bar Status Icons", isOn: Binding(
                    get: { appState.showMenuBarStatus },
                    set: { appState.showMenuBarStatus = $0 }
                ))

                Toggle("Menu Bar Global Shortcut (⌘⌃B)", isOn: Binding(
                    get: { appState.enableKeyboardShortcut },
                    set: { appState.enableKeyboardShortcut = $0 }
                ))
            }

            Section("Permissions") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Full Disk Access")
                            .font(.system(size: 12, weight: .medium))
                        Text(appState.fullDiskAccessGranted
                             ? "Granted ✓"
                             : "Required — click to open settings")
                            .font(.caption)
                            .foregroundStyle(appState.fullDiskAccessGranted ? .green : .red)
                    }
                    .accessibilityElement(children: .combine)

                    Spacer()
                    Button("Open Settings") {
                        PermissionChecker.shared.openFullDiskAccessSettings()
                    }
                }
            }

            Section("Data") {
                Button("Re-scan All Targets") {
                    Task.detached(priority: .userInitiated) {
                        let summary = TargetScanner.shared.summariseAll()
                        await MainActor.run {
                            appState.applyScanSummary(summary)
                        }
                    }
                }

                Button("Run Self-Test…") {
                    Task.detached(priority: .userInitiated) {
                        let reports = SelfTest.run()
                        await MainActor.run {
                            selfTestReports = reports
                            selfTestSheetPresented = true
                        }
                    }
                }

                Button("Preview Next Clean (Dry Run)…") {
                    let jobs = appState.snapshotCleaningJobs()
                    Task.detached(priority: .userInitiated) {
                        let reports = DryRun.plan(jobs: jobs)
                        await MainActor.run {
                            dryRunReports = reports
                            dryRunSheetPresented = true
                        }
                    }
                }

                Button("Save Recovery Script…") {
                    saveUnbrickScript()
                }

                Button("Export Cleaning History…") {
                    exportHistory()
                }

                if let message = unbrickStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Reset All Settings", role: .destructive) {
                    scheduler.stop()
                    appState.resetAll()

                    dismiss()
                    openWindow(id: "onboarding")
                    AppActivator.shared.bringWindowForward(titled: "Welcome to BananaBlitz")
                }
            }

            Section("About") {
                Button("About BananaBlitz") {
                    openWindow(id: "about")
                    AppActivator.shared.bringWindowForward(titled: "About BananaBlitz")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $dryRunSheetPresented) {
            DryRunSheet(reports: dryRunReports) { dryRunSheetPresented = false }
        }
        .sheet(isPresented: $selfTestSheetPresented) {
            SelfTestSheet(reports: selfTestReports) { selfTestSheetPresented = false }
        }
    }

    // MARK: - Updates footer

    @ViewBuilder
    private var updatesFooter: some View {
        if !updater.canCheckForUpdates {
            Text("Updates are disabled because no SUFeedURL is configured. See README → Auto-updates.")
        } else {
            Text("Turn off automatic checks to only check from the BananaBlitz menu or this Settings page.")
        }
    }

    // MARK: - Login Item

    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLog.loginItem.error("Failed to update login item: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - FDA Polling

    /// Refresh the cached FDA status every couple of seconds while Settings
    /// is visible, so the badge updates as the user toggles in System Settings.
    private func pollFullDiskAccess() async {
        while !Task.isCancelled {
            let granted = await Task.detached(priority: .utility) {
                PermissionChecker.shared.hasFullDiskAccess()
            }.value
            await MainActor.run {
                if appState.fullDiskAccessGranted != granted {
                    appState.fullDiskAccessGranted = granted
                }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }

    // MARK: - Unbrick Script Export

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.title = "Export Cleaning History"
        panel.nameFieldStringValue = "bananablitz-history.json"
        panel.message = "Choose .json or .csv. The format is detected from the file extension."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let format: HistoryExporter.Format = url.pathExtension.lowercased() == "csv" ? .csv : .json

        do {
            try HistoryExporter.export(appState.cleaningHistory, format: format, to: url)
            unbrickStatusMessage = "History saved to \(url.path)"
        } catch {
            unbrickStatusMessage = "Export failed: \(error.localizedDescription)"
            AppLog.app.error("History export failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func saveUnbrickScript() {
        let panel = NSSavePanel()
        panel.title = "Save BananaBlitz Recovery Script"
        panel.nameFieldStringValue = "unbrick.sh"
        panel.message = "Exports a shell script that reverses every Lock-with-Immutable-File operation against the current target list."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try UnbrickScriptGenerator.write(to: url, targets: PrivacyTarget.allTargets)
            unbrickStatusMessage = "Saved to \(url.path)"
        } catch {
            unbrickStatusMessage = "Save failed: \(error.localizedDescription)"
            AppLog.app.error("Unbrick script export failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
