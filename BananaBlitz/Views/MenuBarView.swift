import SwiftUI

/// The main menu bar popover view shown when clicking the menu bar icon.
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scheduler: SchedulerService
    @Environment(\.openWindow) private var openWindow
    @State private var pendingCleanReports: [DryRunReport] = []
    @State private var cleanConfirmationPresented = false
    @State private var isPreparingCleanPreview = false
    @State private var cleanOutcome: CleanOutcome?

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
        .sheet(isPresented: $cleanConfirmationPresented) {
            DryRunSheet(
                reports: pendingCleanReports,
                title: "Confirm Blitz",
                confirmTitle: "Blitz Now",
                confirmRole: .destructive,
                onClose: { cleanConfirmationPresented = false },
                onConfirm: {
                    cleanConfirmationPresented = false
                    scheduler.performManualClean { results in
                        // Empty means the run was skipped (another clean in
                        // flight); don't overwrite the last real outcome.
                        guard !results.isEmpty else { return }
                        let succeeded = results.filter(\.success).count
                        cleanOutcome = CleanOutcome(
                            succeeded: succeeded,
                            failed: results.count - succeeded,
                            bytes: results.reduce(Int64(0)) { $0 + $1.bytesReclaimed }
                        )
                    }
                }
            )
        }
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
                title: cleanButtonTitle,
                icon: "bolt.fill",
                isLoading: appState.isCurrentlyCleaning || isPreparingCleanPreview
            ) {
                prepareManualClean()
            }

            if let outcome = cleanOutcome, !appState.isCurrentlyCleaning {
                cleanOutcomeRow(outcome)
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
        HStack(spacing: 12) {
            Button {
                openWindow(id: "settings")
                AppActivator.shared.bringWindowForward(titled: "BananaBlitz Settings")
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

            Button {
                openWindow(id: "about")
                AppActivator.shared.bringWindowForward(titled: "About BananaBlitz")
            } label: {
                Text("About")
                    .font(.system(size: 11))
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
                AppActivator.shared.bringWindowForward(titled: "Welcome to BananaBlitz")
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

    private var cleanButtonTitle: String {
        if appState.isCurrentlyCleaning { return "Cleaning..." }
        if isPreparingCleanPreview { return "Previewing..." }
        return "🍌 Blitz Now"
    }

    /// Inline result of the last manual blitz, so failures aren't invisible
    /// from the menu bar (the Dashboard banner is otherwise the only signal).
    @ViewBuilder
    private func cleanOutcomeRow(_ outcome: CleanOutcome) -> some View {
        HStack(spacing: 6) {
            Image(systemName: outcome.failed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(outcome.failed == 0 ? .green : .orange)

            if outcome.failed == 0 {
                Text("Cleaned \(outcome.succeeded) · \(outcome.bytes.formattedBytes) reclaimed")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                Text("\(outcome.succeeded) cleaned · \(outcome.failed) failed")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                Spacer()
                Button("Details") {
                    openWindow(id: "settings")
                    AppActivator.shared.bringWindowForward(titled: "BananaBlitz Settings")
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.blue)
            }
        }
        .transition(.opacity)
    }

    /// Summary of the most recent manual blitz, shown inline in the popover.
    private struct CleanOutcome {
        let succeeded: Int
        let failed: Int
        let bytes: Int64
    }

    private func prepareManualClean() {
        guard !appState.isCurrentlyCleaning, !isPreparingCleanPreview else { return }

        let jobs = appState.snapshotCleaningJobs()
        guard !jobs.isEmpty else { return }

        cleanOutcome = nil // clear the previous run's result

        isPreparingCleanPreview = true
        Task.detached(priority: .userInitiated) {
            let reports = DryRun.plan(jobs: jobs)
            await MainActor.run {
                pendingCleanReports = reports
                isPreparingCleanPreview = false
                cleanConfirmationPresented = true
            }
        }
    }
}
