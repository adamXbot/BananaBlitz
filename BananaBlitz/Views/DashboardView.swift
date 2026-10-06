import SwiftUI

/// The dashboard, shown in the menu bar popover: three stat tiles, a banner
/// when the last clean had failures, and the recent activity list.
struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    /// Rows shown before the list scrolls.
    private let visibleHistory = 30

    var body: some View {
        VStack(spacing: 10) {
            recentFailureBanner

            // Stat tiles
            HStack(spacing: 8) {
                statTile(
                    title: "Reclaimed",
                    value: appState.totalBytesReclaimed.formattedBytes,
                    icon: "arrow.down.circle.fill",
                    color: .green,
                    accessibility: "Total reclaimed, all time"
                )

                statTile(
                    title: "Targets",
                    value: "\(appState.enabledTargetIDs.count)/\(PrivacyTarget.allTargets.count)",
                    icon: "target",
                    color: .blue,
                    accessibility: "Targets enabled"
                )

                statTile(
                    title: "Last clean",
                    value: lastCleanString,
                    icon: "clock.fill",
                    color: .orange,
                    accessibility: "Last clean"
                )
            }

            // Recent history
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent activity")
                    .font(.system(size: 11, weight: .semibold))

                if appState.cleaningHistory.isEmpty {
                    HStack {
                        Spacer()
                        Text("No cleaning history yet")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(appState.cleaningHistory.prefix(visibleHistory)) { result in
                                historyRow(result)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.controlBackgroundColor).opacity(0.5))
            )
        }
    }

    // MARK: - Components

    private func statTile(title: String, value: String, icon: String, color: Color, accessibility: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accessibility): \(value)")
    }

    private func historyRow(_ result: CleaningResult) -> some View {
        HStack(spacing: 6) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(result.success ? .green : .red)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.targetName)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)

                // Why a target failed, or why a success touched nothing. Both
                // are recorded on every result, so show them.
                if let detail = result.error ?? result.note, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(result.success ? Color.secondary : Color.red)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(detail)
                }
            }

            Spacer()

            if result.bytesReclaimed > 0 {
                Text(result.bytesReclaimed.formattedBytes)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text(result.timestamp, style: .relative)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private var lastCleanString: String {
        guard let date = appState.lastCleanDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Banner visible when the most recent run had any failures.
    /// Walks backwards through history until a successful run breaks the streak.
    @ViewBuilder
    private var recentFailureBanner: some View {
        let recent = recentRunFailures()
        if !recent.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last clean had \(recent.count) failure\(recent.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                    Text(failureLines(recent))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                    )
            )
        }
    }

    /// Failures from the most recent contiguous run. The history is ordered
    /// most-recent-first; a run is the leading slice that shares the same
    /// timestamp minute (close enough for "the last clean").
    private func recentRunFailures() -> [CleaningResult] {
        guard let mostRecent = appState.cleaningHistory.first else { return [] }
        let window: TimeInterval = 60
        let prefix = appState.cleaningHistory.prefix { result in
            mostRecent.timestamp.timeIntervalSince(result.timestamp) <= window
        }
        return prefix.filter { !$0.success }
    }

    /// One line per failure with its reason, capped at three, so the banner
    /// says *why* and not just *what*.
    private func failureLines(_ failures: [CleaningResult]) -> String {
        var lines = failures.prefix(3).map { failure -> String in
            if let reason = failure.error, !reason.isEmpty {
                return "\(failure.targetName): \(reason)"
            }
            return failure.targetName
        }
        if failures.count > 3 {
            lines.append("…and \(failures.count - 3) more")
        }
        return lines.joined(separator: "\n")
    }
}
