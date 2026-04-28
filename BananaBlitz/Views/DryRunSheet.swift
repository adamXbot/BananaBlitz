import SwiftUI

/// Shows what *would* happen if the user clicked Blitz Now, without
/// touching the filesystem.
struct DryRunSheet: View {
    let reports: [DryRunReport]
    let onClose: () -> Void

    private var totalBytes: Int64 {
        reports.reduce(0) { $0 + $1.bytesAtRisk }
    }

    private var totalItems: Int {
        reports.reduce(0) { $0 + $1.itemsAtRisk }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "eye.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
                Text("Preview Next Clean")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Summary
            HStack(spacing: 24) {
                summaryCell("Targets", "\(reports.count)")
                summaryCell("Items", "\(totalItems)")
                summaryCell("Bytes", totalBytes.formattedBytes)
            }
            .padding()

            Divider()

            if reports.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No enabled targets")
                        .foregroundStyle(.secondary)
                }
                .padding(40)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(reports) { report in
                            row(report)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 540, height: 460)
    }

    private func row(_ report: DryRunReport) -> some View {
        HStack(spacing: 10) {
            Image(systemName: report.strategy.icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(report.target.name)
                    .font(.system(size: 12, weight: .medium))
                Text(report.action)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(report.itemsAtRisk) item\(report.itemsAtRisk == 1 ? "" : "s")")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)

            Text(report.bytesAtRisk.formattedBytes)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.controlBackgroundColor).opacity(0.5))
        )
    }

    private func summaryCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
        }
    }
}
