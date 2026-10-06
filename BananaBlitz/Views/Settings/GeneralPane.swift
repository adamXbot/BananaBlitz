import SwiftUI
import UserNotifications

/// Settings ▸ General: startup, the menu bar item, notifications and the
/// Full Disk Access status. The scaffold adds the About button after it.
struct GeneralPane: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var menuBar: SurfaceMenuBarPreference

    @State private var notificationAuthorization: UNAuthorizationStatus?

    private let app = SurfaceApp.bananaBlitz

    var body: some View {
        Section("Startup") {
            SurfaceLaunchAtLoginRow(app: app)
        }

        SurfaceMenuBarSection(app: app, preference: menuBar, icons: MenuBarIconStyle.allCases.map { style in
            SurfaceMenuBarIcon(id: style.rawValue, title: style.displayName, image: style.image)
        }) {
            Toggle(isOn: $appState.showMenuBarStatus) {
                SurfaceInfoLabel(
                    "Show a status badge on the icon",
                    info: "A small dot on the banana: green while the schedule is armed, grey while it is paused, blue during a clean, and orange until setup is finished."
                )
            }
            Toggle(isOn: $appState.enableKeyboardShortcut) {
                SurfaceInfoLabel(
                    "Open with ⌘⌃B from anywhere",
                    info: "A global shortcut that opens the menu bar item from any app. Off by default."
                )
            }
        }

        Section("Notifications") {
            VStack(alignment: .leading, spacing: 6) {
                Picker(selection: notificationStyle) {
                    ForEach(NotificationStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                } label: {
                    SurfaceInfoLabel(
                        "After automatic cleans",
                        info: NotificationStyle.allCases.map(\.detail).joined(separator: " ")
                            + " Failure alerts are always sent, even in Silent mode."
                    )
                }
                .pickerStyle(.segmented)

                notificationWarning
            }
        }
        .task { await refreshNotificationStatus() }

        Section("Permissions") {
            LabeledContent {
                Button("Open System Settings…") {
                    PermissionChecker.shared.openFullDiskAccessSettings()
                }
            } label: {
                SurfaceInfoLabel(
                    "Full Disk Access",
                    info: "macOS protects ~/Library from apps, so BananaBlitz needs Full Disk Access to read and clean the targets. Grant it under Privacy & Security ▸ Full Disk Access; a relaunch is sometimes needed before macOS applies it."
                )
                Text(appState.fullDiskAccessGranted ? "Granted" : "Not granted: protected targets cannot be read or cleaned")
                    .font(.caption)
                    .foregroundStyle(appState.fullDiskAccessGranted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
            }
        }
        .task { await pollFullDiskAccess() }
    }

    // MARK: - Notifications

    private var notificationStyle: Binding<NotificationStyle> {
        Binding(
            get: { appState.notificationStyle },
            set: { appState.notificationStyle = $0 }
        )
    }

    /// Says when the chosen style cannot take effect because macOS has
    /// notifications off, or has never been asked, instead of silently
    /// dropping every alert. Live status, so it sits under the row.
    @ViewBuilder
    private var notificationWarning: some View {
        switch notificationAuthorization {
        case .denied?:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Notifications are turned off for BananaBlitz in System Settings, so clean summaries and failure alerts will not be shown.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open System Settings…") { PermissionChecker.shared.openNotificationSettings() }
                    .controlSize(.small)
            }
        case .notDetermined?:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("macOS has not been asked to allow BananaBlitz notifications yet.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Enable Notifications…") { requestNotificationPermission() }
                    .controlSize(.small)
            }
        default:
            EmptyView()
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            notificationAuthorization = settings.authorizationStatus
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                AppLog.app.error("Notification authorisation failed: \(error.localizedDescription, privacy: .public)")
            }
            Task { await refreshNotificationStatus() }
        }
    }

    // MARK: - Full Disk Access

    /// Refresh the cached status every couple of seconds while the pane is
    /// visible, so the caption updates as the user toggles System Settings.
    private func pollFullDiskAccess() async {
        while !Task.isCancelled {
            let granted = await Task.detached(priority: .utility) {
                PermissionChecker.shared.hasFullDiskAccess()
            }.value
            await MainActor.run {
                if appState.fullDiskAccessGranted != granted {
                    appState.fullDiskAccessGranted = granted
                }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
}
