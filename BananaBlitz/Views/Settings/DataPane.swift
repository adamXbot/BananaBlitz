import AppKit
import SwiftUI

/// Settings ▸ Data: the maintenance actions, exports, snapshots and the
/// reset. Nothing here is a preference; it is the setup the app needs to
/// keep working and the ways out when it does not.
struct DataPane: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scheduler: SchedulerService
    @Environment(\.openWindow) private var openWindow

    @State private var recoveryStatus: String?
    @State private var historyStatus: String?
    @State private var dryRunPresentation: DryRunPresentation?
    @State private var selfTestPresentation: SelfTest.Presentation?

    var body: some View {
        Section("Targets") {
            Button("Re-scan All Targets") {
                Task.detached(priority: .userInitiated) {
                    let summary = TargetScanner.shared.summariseAll()
                    await MainActor.run {
                        appState.applyScanSummary(summary)
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Settings.rescan)

            Button("Run Self-Test…") {
                Task.detached(priority: .userInitiated) {
                    let reports = SelfTest.run()
                    await MainActor.run {
                        selfTestPresentation = SelfTest.Presentation(reports: reports)
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Settings.selfTest)

            Button("Preview Next Clean…") {
                // Preview what the *scheduled* run will actually do: apply
                // the same unattended downgrade so the sheet doesn't show a
                // destructive lock that won't happen on schedule.
                let jobs = SchedulerService.sanitiseForUnattendedRun(
                    appState.snapshotCleaningJobs(),
                    allowAggressive: appState.allowAggressiveScheduledClean
                )
                Task.detached(priority: .userInitiated) {
                    let reports = DryRun.plan(jobs: jobs)
                    await MainActor.run {
                        dryRunPresentation = DryRunPresentation(reports: reports)
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Settings.dryRun)
        }
        // `.sheet(item:)` hands the data to the sheet: with `isPresented` plus
        // a separate array the sheet could open with an empty report list.
        .sheet(item: $dryRunPresentation) { presentation in
            DryRunSheet(reports: presentation.reports) { dryRunPresentation = nil }
        }
        .sheet(item: $selfTestPresentation) { presentation in
            SelfTestSheet(reports: presentation.reports) { selfTestPresentation = nil }
        }

        Section("Recovery") {
            Button("Save Recovery Script…") {
                if let message = ExportActions.saveRecoveryScript() {
                    recoveryStatus = message
                }
            }
            .accessibilityIdentifier(AccessibilityID.Settings.saveRecoveryScript)

            VStack(alignment: .leading, spacing: 4) {
                Button("Create Local Snapshot") {
                    createSnapshot()
                }
                .accessibilityIdentifier(AccessibilityID.Settings.createSnapshot)
                if let recoveryStatus {
                    Text(recoveryStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .accessibilityIdentifier(AccessibilityID.Settings.recoveryStatus)
                        // New identity per message: a text whose string merely
                        // changes can keep a stale accessibility value.
                        .id(recoveryStatus)
                }
            }
        }

        Section("History") {
            VStack(alignment: .leading, spacing: 4) {
                Button("Export Cleaning History…") {
                    if let message = ExportActions.exportHistory(appState.cleaningHistory) {
                        historyStatus = message
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Settings.exportHistory)
                if let historyStatus {
                    Text(historyStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .accessibilityIdentifier(AccessibilityID.Settings.historyStatus)
                        .id(historyStatus)
                }
            }
        }

        Section("Reset") {
            SurfaceDestructiveButton(
                "Reset All Settings…",
                gate: .confirm,
                question: "Reset all BananaBlitz settings?",
                consequence: "This clears your cleaning history, the reclaimed total, your target selection, strategies and schedule, then restarts setup. It cannot be undone. Directories you have locked stay locked: use Unlock in the Targets tab or the recovery script for those.",
                confirmTitle: "Reset Everything"
            ) {
                scheduler.stop()
                appState.resetAll()
                // Close Settings so setup is not left behind it. The dialog is
                // key right now and Settings is its parent; the close is
                // deferred a tick because a window cannot close while the
                // dialog sheet is still attached to it.
                let keyWindow = NSApplication.shared.keyWindow
                let settings = keyWindow?.sheetParent ?? keyWindow
                DispatchQueue.main.async {
                    settings?.close()
                    NSApplication.shared.activate()
                    openWindow(id: "onboarding")
                }
            }
        }
    }

    // MARK: - Snapshot

    private func createSnapshot() {
        recoveryStatus = "Creating local snapshot…"
        SnapshotService.shared.createSnapshot { result in
            switch result {
            case .success(let name):
                let label = name.map { " \($0)" } ?? ""
                recoveryStatus = "Local snapshot\(label) created. Restore individual files by entering Time Machine."
            case .failure(let message):
                recoveryStatus = "Snapshot failed: \(message)"
            }
        }
    }
}
