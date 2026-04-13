import SwiftUI

/// The main menu bar popover view shown when clicking the menu bar icon.
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scheduler: SchedulerService
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider().opacity(0.3)

            if !appState.hasCompletedOnboarding {
                onboardingPrompt
            } else {
                // Quick stats
                statsSection

                // Blitz Now button
                actionSection

                Divider().opacity(0.3)

                // Target summary by level
                targetSummarySection

                Divider().opacity(0.3)

                // Footer
                footerSection
            }
        }
        .frame(width: 320)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("🍌")
                .font(.title2)
            Text("BananaBlitz")
                .font(.system(size: 15, weight: .bold, design: .rounded))

            Spacer()

            // Status dot
            StatusDot(color: statusColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(appState.statusSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if scheduler.isActive, let timeLeft = scheduler.timeUntilNextClean {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text("Next clean \(timeLeft)")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(appState.totalBytesReclaimed.formattedBytes)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("total reclaimed (all time)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Action

    private var actionSection: some View {
        VStack(spacing: 8) {
            CleanButton(
                title: appState.isCurrentlyCleaning ? "Cleaning..." : "🍌 Blitz Now",
                icon: "bolt.fill",
                isLoading: appState.isCurrentlyCleaning
            ) {
                scheduler.performManualClean { _ in }
            }

            // Schedule toggle
            HStack {
                Text(appState.scheduleInterval.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    appState.isPaused.toggle()
                    scheduler.updateSchedule()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: appState.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 9))
                        Text(appState.isPaused ? "Resume" : "Pause")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(appState.isPaused ? .orange : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Target Summary

    private var targetSummarySection: some View {
        VStack(spacing: 2) {
            ForEach(CleaningLevel.allCases) { level in
                targetLevelRow(level)
            }
        }
        .padding(.vertical, 6)
    }

    private func targetLevelRow(_ level: CleaningLevel) -> some View {
        let targets = PrivacyTarget.allTargets.filter { $0.level == level }
        let enabledCount = targets.filter { appState.isTargetEnabled($0) }.count
        let totalSize = targets.reduce(Int64(0)) { $0 + (appState.scanResults[$1.id] ?? 0) }

        return HStack(spacing: 8) {
            Text(level.emoji)
                .font(.system(size: 11))

            Text(level.displayName)
                .font(.system(size: 11, weight: .medium))

            Spacer()

            Text("\(enabledCount)/\(targets.count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)

            if totalSize > 0 {
                SizeLabel(bytes: totalSize, style: .compact)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gear")
                        .font(.system(size: 11))
                    Text("Settings")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Onboarding Prompt

    private var onboardingPrompt: some View {
        VStack(spacing: 12) {
            Text("Welcome! Let's set up your privacy cleaning.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            CleanButton(title: "Get Started", icon: "arrow.right") {
                openWindow(id: "onboarding")
            }
        }
        .padding(20)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        if appState.isCurrentlyCleaning { return .blue }
        if appState.isPaused { return .orange }
        guard let last = appState.lastCleanDate else { return .gray }

        let elapsed = Date().timeIntervalSince(last)
        let interval = appState.scheduleInterval.rawValue

        if interval == 0 { return .green }
        if elapsed < interval { return .green }
        if elapsed < interval * 2 { return .orange }
        return .red
    }
}
