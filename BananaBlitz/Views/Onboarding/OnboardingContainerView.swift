import SwiftUI

/// Multi-step onboarding wizard container.
struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scheduler: SchedulerService
    @Environment(\.dismiss) private var dismiss

    /// Persisted across launches so quitting mid-onboarding (e.g. to grant
    /// Full Disk Access in System Settings, which often requires a relaunch)
    /// drops the user back on the same step. Cleared on completion and on
    /// `AppState.resetAll()`.
    @AppStorage(StorageKey.onboardingStep) private var currentStep: Int = 0

    @State private var scanResults: [String: Int64] = [:]
    @State private var isScanning = false

    private let totalSteps = 7

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar

            // Step content
            Group {
                switch currentStep {
                case 0: WelcomeStepView()
                case 1: PermissionStepView()
                case 2: ScanStepView(scanResults: $scanResults, isScanning: $isScanning)
                case 3: SnapshotStepView()
                case 4: LevelPickerStepView(scanResults: scanResults)
                case 5: ScheduleStepView()
                case 6: CleanStepView(scanResults: scanResults)
                default: WelcomeStepView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 28)

            Divider().opacity(0.3)

            // Navigation buttons
            navigationBar
        }
        .frame(width: 720, height: 580)
        .background(
            LinearGradient(
                colors: [
                    Color(.windowBackgroundColor),
                    Color(.windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear { resumeIfNeeded() }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.separatorColor).opacity(0.3))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.bananaGold, .bananaGoldDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
                    .animation(.easeInOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep -= 1
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Step indicator
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer()

            if currentStep < totalSteps - 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        handleNext()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(nextButtonTitle)
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.bananaGold)
                    )
                    .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .disabled(!canProceed)
            } else {
                Button {
                    finishOnboarding()
                } label: {
                    HStack(spacing: 4) {
                        Text("Finish")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "checkmark")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Logic

    private var progress: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }

    private var canProceed: Bool {
        switch currentStep {
        case 1: return appState.fullDiskAccessGranted
        case 2: return !isScanning
        default: return true
        }
    }

    private var nextButtonTitle: String {
        switch currentStep {
        case 1: return appState.fullDiskAccessGranted ? "Continue" : "Waiting..."
        case 2: return isScanning ? "Scanning..." : "Continue"
        default: return "Continue"
        }
    }

    private func handleNext() {
        if currentStep == 1 {
            // Moving from permission step to scan — start scanning
            currentStep += 1
            startScan()
        } else {
            currentStep += 1
        }
    }

    private func startScan() {
        isScanning = true
        Task.detached(priority: .userInitiated) {
            let summary = TargetScanner.shared.summariseAll()
            await MainActor.run {
                scanResults = summary.sizes
                appState.applyScanSummary(summary)
                isScanning = false
            }
        }
    }

    private func finishOnboarding() {
        appState.hasCompletedOnboarding = true
        // Reset wizard state so a future Reset All Settings starts on step 0.
        currentStep = 0
        scheduler.configure(with: appState)
        dismiss()
    }

    /// Called from `.onAppear`. Handles two cases:
    ///   1. Persisted step is out of valid range — clamp to a safe value.
    ///   2. User resumed on the scan step (2) but the in-memory `scanResults`
    ///      is empty (because that's `@State` and got wiped on relaunch).
    ///      Re-run the scan so the user isn't stuck on an empty screen.
    private func resumeIfNeeded() {
        if currentStep < 0 || currentStep >= totalSteps {
            currentStep = 0
        }
        if currentStep == 2 && scanResults.isEmpty && !isScanning {
            startScan()
        }
    }
}
