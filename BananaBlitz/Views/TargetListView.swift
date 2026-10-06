import SwiftUI

/// Settings ▸ Targets: every privacy target by cleaning level, with toggles,
/// strategy pickers and the only in-app Unlock.
struct TargetListView: View {
    @EnvironmentObject var appState: AppState

    @State private var searchText = ""
    @State private var filterLevel: CleaningLevel?
    @State private var unlockError: String?

    /// The list scrolls inside the pane so the window keeps a sane height.
    private let listHeight: CGFloat = 400

    var body: some View {
        Section {
            TextField("Search", text: $searchText, prompt: Text("Name, description or path"))
                .textFieldStyle(.roundedBorder)

            Picker("Show", selection: $filterLevel) {
                Text("All levels").tag(CleaningLevel?.none)
                ForEach(CleaningLevel.allCases) { level in
                    Text("\(level.emoji) \(level.displayName)").tag(CleaningLevel?.some(level))
                }
            }
            .pickerStyle(.menu)
        }

        Section {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(CleaningLevel.allCases) { level in
                        let targets = filteredTargets(for: level)
                        if !targets.isEmpty {
                            levelSection(level, targets: targets)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: listHeight)
        }
        .alert("Couldn't unlock", isPresented: Binding(
            get: { unlockError != nil },
            set: { if !$0 { unlockError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(unlockError ?? "")
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
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            // Target rows. Lock state is read from AppState's cache so we
            // never hit the filesystem inside a view body.
            ForEach(targets) { target in
                TargetRowView(
                    target: target,
                    size: appState.scanResults[target.id] ?? 0,
                    isEnabled: appState.isTargetEnabled(target),
                    isLocked: appState.lockStates[target.id] ?? false,
                    isPresent: appState.targetPresence[target.id] ?? true,
                    strategy: appState.strategyFor(target),
                    onToggle: { appState.toggleTarget(target) },
                    onStrategyChange: { appState.setStrategy($0, for: target) },
                    onVerify: { verify(target) },
                    onUnlock: { unlock(target) }
                )
            }

            if level != .paranoid {
                Divider()
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Helpers

    private func filteredTargets(for level: CleaningLevel) -> [PrivacyTarget] {
        // Filter by selected level
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

    /// Refresh the cached size, lock state and presence for a single target.
    private func verify(_ target: PrivacyTarget) {
        Task.detached(priority: .userInitiated) {
            await refreshCaches(for: target)
        }
    }

    /// Explicitly remove a BananaBlitz lock. This is the only in-app way to
    /// unlock — no cleaning strategy removes a lock as a side effect.
    private func unlock(_ target: PrivacyTarget) {
        Task.detached(priority: .userInitiated) {
            do {
                try PrivacyCleaner.shared.unlock(target: target)
            } catch {
                await MainActor.run { unlockError = error.localizedDescription }
            }
            await refreshCaches(for: target)
        }
    }

    private func refreshCaches(for target: PrivacyTarget) async {
        let size = TargetScanner.shared.targetSize(target)
        let locked = TargetScanner.shared.isLocked(target)
        let present = TargetScanner.shared.targetExists(target)
        await MainActor.run {
            appState.scanResults[target.id] = size
            appState.lockStates[target.id] = locked
            appState.targetPresence[target.id] = present
        }
    }
}
