import SwiftUI

/// Step 3: Scan all targets and show categorised results.
struct ScanStepView: View {
    @EnvironmentObject var appState: AppState
    @Binding var scanResults: [String: Int64]
    @Binding var isScanning: Bool

    @State private var revealedLevels: Set<CleaningLevel> = []

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Text(isScanning ? "Scanning your system..." : "Scan Complete")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                if isScanning {
                    ProgressView()
                        .controlSize(.regular)
                        .padding(.top, 4)
                } else {
                    Text("Found \(totalSize.formattedBytes) of tracking data across \(foundTargetCount) targets")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 16)

            if !isScanning {
                // Categorised results
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(CleaningLevel.allCases) { level in
                            levelCard(level)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .padding(16)
        .onAppear {
            // Stagger the reveal animation
            if !isScanning {
                animateReveal()
            }
        }
        .onChange(of: isScanning) { _, newValue in
            if !newValue {
                animateReveal()
            }
        }
    }

    // MARK: - Level Card

    private func levelCard(_ level: CleaningLevel) -> some View {
        let targets = PrivacyTarget.allTargets.filter { $0.level == level }
        let levelSize = targets.reduce(Int64(0)) { $0 + (scanResults[$1.id] ?? 0) }
        let foundCount = targets.filter { (scanResults[$0.id] ?? 0) > 0 }.count
        let isRevealed = revealedLevels.contains(level)

        return VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                Text(level.emoji)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.system(size: 14, weight: .semibold))

                    Text(levelDescription(level))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(levelSize.formattedBytes)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("\(foundCount) target\(foundCount == 1 ? "" : "s") found")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            // Target list (collapsed by default, expandable)
            if isRevealed {
                VStack(spacing: 4) {
                    ForEach(targets) { target in
                        let size = scanResults[target.id] ?? 0
                        HStack(spacing: 8) {
                            Circle()
                                .fill(size > 0 ? level.color : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)

                            Text(target.name)
                                .font(.system(size: 11))
                                .foregroundStyle(size > 0 ? .primary : .tertiary)

                            Spacer()

                            if size > 0 {
                                Text(size.formattedBytes)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("not found")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.quaternary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(level.color.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(isRevealed ? 1 : 0)
        .offset(y: isRevealed ? 0 : 10)
        .onTapGesture {
            // Toggle expansion could be added here
        }
    }

    // MARK: - Helpers

    private var totalSize: Int64 {
        scanResults.values.reduce(0, +)
    }

    private var foundTargetCount: Int {
        scanResults.filter { $0.value > 0 }.count
    }

    private func levelDescription(_ level: CleaningLevel) -> String {
        switch level {
        case .harmless: return "Always safe to clean"
        case .strong:   return "Smart features may degrade"
        case .paranoid: return "Some things may break"
        }
    }

    private func animateReveal() {
        for (index, level) in CleaningLevel.allCases.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.25) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    _ = revealedLevels.insert(level)
                }
            }
        }
    }
}
