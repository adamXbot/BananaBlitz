import SwiftUI
import AppKit

/// Shows what *would* happen if the user clicked Blitz Now, without
/// touching the filesystem.
struct DryRunSheet: View {
    let reports: [DryRunReport]
    let title: String
    let confirmTitle: String?
    let confirmRole: ButtonRole?
    let onClose: () -> Void
    let onConfirm: (() -> Void)?

    @State private var saveMessage: String?

    /// True if any job deletes-then-locks (the destructive `replaceWithFile`).
    private var hasAggressive: Bool {
        reports.contains { $0.strategy.isAggressive }
    }

    init(reports: [DryRunReport], onClose: @escaping () -> Void) {
        self.reports = reports
        self.title = "Preview Next Clean"
        self.confirmTitle = nil
        self.confirmRole = nil
        self.onClose = onClose
        self.onConfirm = nil
    }

    init(
        reports: [DryRunReport],
        title: String,
        confirmTitle: String,
        confirmRole: ButtonRole? = nil,
        onClose: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.reports = reports
        self.title = title
        self.confirmTitle = confirmTitle
        self.confirmRole = confirmRole
        self.onClose = onClose
        self.onConfirm = onConfirm
    }

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
                Text(title)
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

            if let onConfirm, let confirmTitle {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(footerWarning)
                        .font(.system(size: 10))
                        .foregroundStyle(hasAggressive ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 10) {
                        if let saveMessage {
                            Text(saveMessage)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        if hasAggressive {
                            Button("Save Recovery Script…") { saveRecoveryScript() }
                        }

                        Button("Cancel", action: onClose)
                            .keyboardShortcut(.cancelAction)

                        Button(confirmTitle, role: confirmRole) {
                            onConfirm()
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(reports.isEmpty)
                    }
                }
                .padding()
            }
        }
        .frame(width: 540, height: 460)
    }

    private func row(_ report: DryRunReport) -> some View {
        let aggressive = report.strategy.isAggressive
        return HStack(spacing: 10) {
            Image(systemName: report.strategy.icon)
                .font(.system(size: 11))
                .foregroundStyle(aggressive ? .orange : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(report.target.name)
                        .font(.system(size: 12, weight: .medium))
                    if aggressive {
                        Text("DELETES, THEN LOCKS")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.orange))
                            .accessibilityLabel("Destructive: deletes the directory, then locks it")
                    }
                }
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
                .fill(aggressive ? Color.orange.opacity(0.12) : Color(.controlBackgroundColor).opacity(0.5))
        )
    }

    private var footerWarning: String {
        if hasAggressive {
            return "Highlighted targets are deleted and replaced with a locked file. The lock is reversible with the recovery script — but the deleted contents are not recoverable. Save the script first."
        }
        return "Contents are deleted; the system daemons recreate them as needed. Nothing is locked."
    }

    /// Offer the recovery script at the moment of risk, so the user doesn't
    /// have to hunt for it in Settings after locking something.
    private func saveRecoveryScript() {
        let panel = NSSavePanel()
        panel.title = "Save BananaBlitz Recovery Script"
        panel.nameFieldStringValue = "unbrick.sh"
        panel.message = "Run this in Terminal to reverse every lock BananaBlitz can apply."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try UnbrickScriptGenerator.write(to: url)
            saveMessage = "Recovery script saved to \(url.lastPathComponent)"
        } catch {
            saveMessage = "Save failed: \(error.localizedDescription)"
            AppLog.app.error("Recovery script save failed: \(error.localizedDescription, privacy: .public)")
        }
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
