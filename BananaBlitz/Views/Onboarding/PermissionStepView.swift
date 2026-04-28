import SwiftUI

/// Step 2: Guide the user to grant Full Disk Access.
struct PermissionStepView: View {
    @EnvironmentObject var appState: AppState
    @State private var hasAccess = false
    @State private var checkTimer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(hasAccess ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: hasAccess ? "checkmark.shield.fill" : "lock.shield")
                    .font(.system(size: 36))
                    .foregroundStyle(hasAccess ? .green : .orange)
                    .symbolEffect(.bounce, value: hasAccess)
            }

            VStack(spacing: 8) {
                Text(hasAccess ? "Full Disk Access Granted" : "Full Disk Access Required")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text(hasAccess
                     ? "BananaBlitz can now access and clean protected system folders."
                     : "BananaBlitz needs Full Disk Access to read and clean protected folders in ~/Library.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            if !hasAccess {
                VStack(spacing: 16) {
                    // Steps
                    VStack(alignment: .leading, spacing: 12) {
                        stepRow(number: 1, text: "Click the button below to open System Settings")
                        stepRow(number: 2, text: "Find BananaBlitz in the Full Disk Access list")
                        stepRow(number: 3, text: "Toggle it ON and come back here")
                    }
                    .padding(.horizontal, 60)

                    // Open Settings button
                    Button {
                        PermissionChecker.shared.openFullDiskAccessSettings()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "gear")
                                .font(.system(size: 14))
                            Text("Open System Settings")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    // Polling indicator
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking for access...")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(24)
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    // MARK: - Components

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.orange.opacity(0.8)))

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Polling

    private func startPolling() {
        hasAccess = PermissionChecker.shared.hasFullDiskAccess()
        appState.fullDiskAccessGranted = hasAccess
        guard !hasAccess else { return }

        checkTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            let access = PermissionChecker.shared.hasFullDiskAccess()
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    hasAccess = access
                }
                appState.fullDiskAccessGranted = access
                if access { stopPolling() }
            }
        }
    }

    private func stopPolling() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
}
