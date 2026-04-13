import SwiftUI
import ServiceManagement

/// Settings window with tabs for Schedule, Targets, and Preferences.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scheduler: SchedulerService

    @State private var selectedTab = 0

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

                Text(appState.selectedLevel.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Default Cleaning Strategy") {
                ForEach(CleaningStrategy.allCases) { strategy in
                    HStack(spacing: 10) {
                        Image(systemName: strategy.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading) {
                            Text(strategy.displayName)
                                .font(.system(size: 12, weight: .medium))
                            Text(strategy.description)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if strategy.isAggressive {
                            LevelBadge(level: .paranoid)
                        }
                    }
                    .padding(.vertical, 4)
                }
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

            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { newValue in
                        appState.launchAtLogin = newValue
                        updateLoginItem(enabled: newValue)
                    }
                ))
            }

            Section("Permissions") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Full Disk Access")
                            .font(.system(size: 12, weight: .medium))
                        Text(PermissionChecker.shared.hasFullDiskAccess()
                             ? "Granted ✓"
                             : "Required — click to open settings")
                            .font(.caption)
                            .foregroundStyle(
                                PermissionChecker.shared.hasFullDiskAccess() ? .green : .red
                            )
                    }
                    Spacer()
                    Button("Open Settings") {
                        PermissionChecker.shared.openFullDiskAccessSettings()
                    }
                }
            }

            Section("Data") {
                Button("Re-scan All Targets") {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let results = TargetScanner.shared.scanAll()
                        DispatchQueue.main.async {
                            appState.scanResults = results
                        }
                    }
                }

                Button("Reset All Settings", role: .destructive) {
                    appState.hasCompletedOnboarding = false
                    appState.enabledTargetIDs.removeAll()
                    appState.cleaningHistory.removeAll()
                    appState.totalBytesReclaimed = 0
                    appState.lastCleanDate = nil
                    appState.savePersistedData()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
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
            print("Failed to update login item: \(error)")
        }
    }
}
