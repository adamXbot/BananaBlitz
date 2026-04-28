import SwiftUI

struct SelfTestSheet: View {
    let reports: [SelfTest.Report]
    let onClose: () -> Void

    private var deniedCount: Int { reports.filter { $0.status == .denied }.count }
    private var lockedCount: Int { reports.filter { $0.status == .locked }.count }
    private var okCount: Int { reports.filter { $0.status == .ok }.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: deniedCount > 0 ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                    .foregroundStyle(deniedCount > 0 ? .orange : .green)
                    .font(.title3)
                Text("Self-Test Report")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Summary header
            HStack(spacing: 16) {
                summary("Healthy", value: okCount, color: .green)
                summary("Locked", value: lockedCount, color: .orange)
                summary("Denied", value: deniedCount, color: .red)
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(reports) { report in
                        row(report)
                    }
                }
                .padding()
            }
        }
        .frame(width: 540, height: 460)
    }

    private func row(_ report: SelfTest.Report) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon(for: report.status))
                .foregroundStyle(color(for: report.status))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(report.target.name)
                    .font(.system(size: 12, weight: .medium))
                Text(report.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(report.status.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color(for: report.status))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.controlBackgroundColor).opacity(0.5))
        )
    }

    private func summary(_ label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label): \(value)")
                .font(.system(size: 11))
        }
    }

    private func icon(for status: SelfTest.Status) -> String {
        switch status {
        case .ok:              return "checkmark.circle.fill"
        case .missing:         return "questionmark.circle"
        case .denied:          return "lock.slash.fill"
        case .locked:          return "lock.fill"
        case .unexpectedFile:  return "exclamationmark.triangle.fill"
        }
    }

    private func color(for status: SelfTest.Status) -> Color {
        switch status {
        case .ok:              return .green
        case .missing:         return .secondary
        case .denied:          return .red
        case .locked:          return .orange
        case .unexpectedFile:  return .yellow
        }
    }
}
