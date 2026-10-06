import SwiftUI

/// Settings ▸ Schedule: how often to clean, the default level and the
/// strategy applied across targets.
struct SchedulePane: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scheduler: SchedulerService

    var body: some View {
        Section("Cleaning schedule") {
            Picker("Interval", selection: Binding(
                get: { appState.scheduleInterval },
                set: {
                    appState.scheduleInterval = $0
                    scheduler.updateSchedule()
                }
            )) {
                ForEach(ScheduleInterval.allCases) { interval in
                    Text(interval.displayName).tag(interval)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Pause schedule", isOn: Binding(
                    get: { appState.isPaused },
                    set: {
                        appState.isPaused = $0
                        scheduler.updateSchedule()
                    }
                ))

                if scheduler.isActive, let timeLeft = scheduler.timeUntilNextClean {
                    Text("Next clean \(timeLeft)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $appState.allowAggressiveScheduledClean) {
                SurfaceInfoLabel(
                    "Allow locking on schedule",
                    info: "Scheduled cleans run with no confirmation, so by default the destructive Lock with Immutable File strategy is downgraded to a plain wipe for unattended runs. Turn this on only if you want directories deleted and locked automatically."
                )
            }
        }

        Section("Cleaning level") {
            Picker(selection: Binding(
                get: { appState.selectedLevel },
                set: {
                    appState.selectedLevel = $0
                    appState.setDefaultTargets(for: $0)
                }
            )) {
                ForEach(CleaningLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            } label: {
                SurfaceInfoLabel(
                    "Default level",
                    info: CleaningLevel.allCases
                        .map { "\($0.displayName): \($0.description)" }
                        .joined(separator: " ")
                        + " Choosing a level re-selects its targets; fine-tune them in the Targets tab."
                )
            }
            .pickerStyle(.segmented)
        }

        Section("Strategy") {
            Picker(selection: Binding(
                get: { appState.globalStrategy },
                set: { appState.globalStrategy = $0 }
            )) {
                ForEach(CleaningStrategy.allCases) { strategy in
                    Text(strategy.displayName).tag(strategy)
                }
            } label: {
                SurfaceInfoLabel(
                    "Strategy override",
                    info: CleaningStrategy.allCases
                        .map { "\($0.displayName): \($0.description)" }
                        .joined(separator: " ")
                        + " Choosing one applies it to every enabled target that supports it; per-target strategies live in the Targets tab."
                )
            }
            .pickerStyle(.menu)
        }
    }
}
