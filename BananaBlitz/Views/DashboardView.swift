import SwiftUI

/// Dashboard showing an overview of recent cleaning activity and stats.
struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            // Hero stat cards
            HStack(spacing: 16) {
                statCard(
                    title: "Total Reclaimed",
                    value: appState.totalBytesReclaimed.formattedBytes,
                    icon: "arrow.down.circle.fill",
                    color: .green
                )

                statCard(
                    title: "Targets Enabled",
                    value: "\(appState.enabledTargetIDs.count) / \(PrivacyTarget.allTargets.count)",
                    icon: "target",
                    color: .blue
                )

                statCard(
                    title: "Last Clean",
                    value: lastCleanString,
                    icon: "clock.fill",
                    color: .orange
                )
            }

            // Recent history
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity")
                    .font(.headline)

                if appState.cleaningHistory.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No cleaning history yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 30)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(appState.cleaningHistory.prefix(30)) { result in
                                historyRow(result)
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor).opacity(0.5))
            )
        }
    }

    // MARK: - Components

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func historyRow(_ result: CleaningResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(result.success ? .green : .red)

            Text(result.targetName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)

            Spacer()

            if result.bytesReclaimed > 0 {
                Text(result.bytesReclaimed.formattedBytes)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text(result.timestamp, style: .relative)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private var lastCleanString: String {
        guard let date = appState.lastCleanDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
