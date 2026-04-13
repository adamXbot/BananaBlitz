import SwiftUI

/// Step 4: Choose the default cleaning level.
struct LevelPickerStepView: View {
    @EnvironmentObject var appState: AppState
    let scanResults: [String: Int64]

    @State private var selectedLevel: CleaningLevel = .strong
    @State private var isRevealed = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Choose Your Level")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("This pre-selects which targets to clean. You can always customise individual targets later.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 450)
            }
            .padding(.top, 16)

            // Level cards
            HStack(spacing: 16) {
                ForEach(CleaningLevel.allCases) { level in
                    levelCard(level)
                }
            }
            .padding(.horizontal, 24)
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 20)

            // Summary of selection
            if isRevealed {
                selectionSummary
                    .transition(.opacity)
            }

            Spacer()
        }
        .padding(16)
        .onAppear {
            selectedLevel = appState.selectedLevel
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                isRevealed = true
            }
        }
        .onChange(of: selectedLevel) { _, newLevel in
            appState.selectedLevel = newLevel
            appState.setDefaultTargets(for: newLevel)
        }
    }

    // MARK: - Level Card

    private func levelCard(_ level: CleaningLevel) -> some View {
        let isSelected = selectedLevel == level
        let targets = PrivacyTarget.targets(for: level)
        let levelSize = targets.reduce(Int64(0)) { $0 + (scanResults[$1.id] ?? 0) }

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedLevel = level
            }
        } label: {
            VStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(level.color.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 56, height: 56)

                    Image(systemName: level.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(level.color)
                        .symbolEffect(.bounce, value: isSelected)
                }

                // Label
                Text(level.emoji + " " + level.displayName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                // Description
                Text(level.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Stats
                VStack(spacing: 4) {
                    Text("\(targets.count) targets")
                        .font(.system(size: 12, weight: .medium))
                    Text(levelSize.formattedBytes)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 230)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.controlBackgroundColor).opacity(isSelected ? 0.8 : 0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ? level.color : Color(.separatorColor).opacity(0.3),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? level.color.opacity(0.2) : .clear,
                        radius: 8,
                        y: 4
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Summary

    private var selectionSummary: some View {
        let targets = PrivacyTarget.targets(for: selectedLevel)

        return HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedLevel.displayName) level: \(targets.count) targets will be cleaned")
                    .font(.system(size: 12, weight: .medium))

                Text("You can enable/disable individual targets in Settings after setup.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor).opacity(0.5))
        )
        .padding(.horizontal, 24)
    }
}
