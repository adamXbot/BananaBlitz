import SwiftUI

/// Full list of privacy targets organised by cleaning level, with toggles and strategy pickers.
struct TargetListView: View {
    @EnvironmentObject var appState: AppState

    @State private var searchText = ""
    @State private var filterLevel: CleaningLevel?

    var body: some View {
        VStack(spacing: 0) {
            // Search and filter bar
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    TextField("Search targets...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.controlBackgroundColor))
                )

                // Level filter pills
                HStack(spacing: 4) {
                    filterPill(nil, label: "All")
                    ForEach(CleaningLevel.allCases) { level in
                        filterPill(level, label: level.emoji)
                    }
                }
            }
            .padding()

            Divider()

            // Target list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(CleaningLevel.allCases) { level in
                        let targets = filteredTargets(for: level)
                        if !targets.isEmpty {
                            levelSection(level, targets: targets)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Level Section

    private func levelSection(_ level: CleaningLevel, targets: [PrivacyTarget]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section header
            HStack(spacing: 6) {
                Text(level.emoji)
                Text(level.displayName)
                    .font(.system(size: 12, weight: .semibold))
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(level.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()

                // Enable/disable all in section
                Button {
                    toggleAll(level: level, targets: targets)
                } label: {
                    Text(allEnabled(targets) ? "Disable All" : "Enable All")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Target rows. Lock state is read from AppState's cache so we
            // never hit the filesystem inside a view body.
            ForEach(targets) { target in
                TargetRowView(
                    target: target,
                    size: appState.scanResults[target.id] ?? 0,
                    isEnabled: appState.isTargetEnabled(target),
                    isLocked: appState.lockStates[target.id] ?? false,
                    strategy: appState.strategyFor(target),
                    onToggle: { appState.toggleTarget(target) },
                    onStrategyChange: { appState.setStrategy($0, for: target) },
                    onVerify: { verify(target) }
                )
                .padding(.horizontal, 8)
            }

            if level != .paranoid {
                Divider()
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Filter Pill

    private func filterPill(_ level: CleaningLevel?, label: String) -> some View {
        let isSelected = filterLevel == level

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                filterLevel = level
            }
        } label: {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func filteredTargets(for level: CleaningLevel) -> [PrivacyTarget] {
        // Filter by selected level tab
        if let filter = filterLevel, filter != level { return [] }

        let targets = PrivacyTarget.allTargets.filter { $0.level == level }

        if searchText.isEmpty { return targets }

        return targets.filter { target in
            target.name.localizedCaseInsensitiveContains(searchText) ||
            target.description.localizedCaseInsensitiveContains(searchText) ||
            target.path.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func allEnabled(_ targets: [PrivacyTarget]) -> Bool {
        targets.allSatisfy { appState.isTargetEnabled($0) }
    }

    private func toggleAll(level: CleaningLevel, targets: [PrivacyTarget]) {
        let enable = !allEnabled(targets)
        for target in targets {
            if enable && !appState.isTargetEnabled(target) {
                appState.toggleTarget(target)
            } else if !enable && appState.isTargetEnabled(target) {
                appState.toggleTarget(target)
            }
        }
    }

    /// Refresh the cached size + lock state for a single target.
    private func verify(_ target: PrivacyTarget) {
        Task.detached(priority: .userInitiated) {
            let size = TargetScanner.shared.targetSize(target)
            let locked = TargetScanner.shared.isLocked(target)
            await MainActor.run {
                appState.scanResults[target.id] = size
                appState.lockStates[target.id] = locked
            }
        }
    }
}
