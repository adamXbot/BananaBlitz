import SwiftUI
import ServiceManagement

/// Step 5: Configure scheduling and background launch behaviour.
struct ScheduleStepView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scheduler: SchedulerService

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                Text("Set and Forget")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("BananaBlitz can run stealthily in the background to ensure your tracking targets stay empty.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            VStack(spacing: 16) {
                // Schedule Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("How often should we clean?")
                        .font(.system(size: 12, weight: .semibold))
                    
                    Picker("", selection: Binding(
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
                    .labelsHidden()
                    .frame(width: 200)
                }
                .padding(16)
                .frame(maxWidth: 320)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor).opacity(0.5))
                )

                // Launch at Login. The toggle reflects whatever the user
                // chooses — we never silently flip it on for them.
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: Binding(
                        get: { appState.launchAtLogin },
                        set: { newValue in
                            appState.launchAtLogin = newValue
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                AppLog.loginItem.error("Failed to update login item: \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Recommended to keep your system clean automatically.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .padding(16)
                .frame(maxWidth: 320)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor).opacity(0.5))
                )
            }

            Spacer()
        }
        .padding(24)
    }
}
