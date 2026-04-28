import SwiftUI

/// A single row displaying a privacy target with its status, size, and controls.
struct TargetRowView: View {
    let target: PrivacyTarget
    let size: Int64
    let isEnabled: Bool
    let isLocked: Bool
    let strategy: CleaningStrategy
    let onToggle: () -> Void
    let onStrategyChange: (CleaningStrategy) -> Void
    var onVerify: (() -> Void)? = nil

    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 10) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: statusIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(target.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)

                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(target.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 1)
                }

                Spacer()

                // Size
                if size > 0 {
                    SizeLabel(bytes: size, style: .compact)
                }

                // Toggle
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("Side-effect: \(target.sideEffect)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text(target.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    if target.supportedStrategies.count > 1 {
                        HStack(spacing: 4) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Text("Strategy:")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            Picker("", selection: Binding(
                                get: { strategy },
                                set: { onStrategyChange($0) }
                            )) {
                                ForEach(target.supportedStrategies) { s in
                                    Text(s.displayName).tag(s)
                                }
                            }
                            .pickerStyle(.menu)
                            .controlSize(.mini)
                            .labelsHidden()
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Text("Strategy: \(strategy.displayName) (Only supported method)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let onVerify = onVerify {
                        Button {
                            onVerify()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Verify state")
                            }
                            .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(.controlBackgroundColor).opacity(0.5) : .clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
    }

    private var statusColor: Color {
        if isLocked { return .orange }
        if !isEnabled { return .gray }
        return target.level.color
    }

    private var statusIcon: String {
        if isLocked { return "lock.fill" }
        if !isEnabled { return "circle.dashed" }
        return target.level.icon
    }
}
