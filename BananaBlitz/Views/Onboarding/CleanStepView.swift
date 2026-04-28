import SwiftUI

/// Step 5: Execute the initial clean with a satisfying animation.
struct CleanStepView: View {
    @EnvironmentObject var appState: AppState
    let scanResults: [String: Int64]

    @State private var isCleaning = false
    @State private var isComplete = false
    @State private var progress: Double = 0
    @State private var cleanedCount = 0
    @State private var totalReclaimed: Int64 = 0
    @State private var currentTarget: String = ""
    @State private var results: [CleaningResult] = []

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if isComplete {
                completionView
            } else if isCleaning {
                cleaningView
            } else {
                readyView
            }

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Ready State

    private var readyView: some View {
        VStack(spacing: 20) {
            // Banana icon
            Text("🍌")
                .font(.system(size: 70))

            VStack(spacing: 8) {
                Text("Ready to Blitz!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                let targets = appState.enabledTargets
                let totalSize = targets.reduce(Int64(0)) { $0 + (scanResults[$1.id] ?? 0) }

                Text("Will clean \(targets.count) targets · \(totalSize.formattedBytes) estimated")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            CleanButton(
                title: "🍌 Blitz It!",
                icon: "bolt.fill"
            ) {
                startCleaning()
            }
            .frame(width: 200)
        }
    }

    // MARK: - Cleaning State

    private var cleaningView: some View {
        VStack(spacing: 20) {
            // Animated banana
            Text("🍌")
                .font(.system(size: 60))
                .rotationEffect(.degrees(isCleaning ? 360 : 0))
                .animation(
                    .linear(duration: 2).repeatForever(autoreverses: false),
                    value: isCleaning
                )

            VStack(spacing: 8) {
                Text("Cleaning in progress...")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Text(currentTarget)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.separatorColor).opacity(0.3))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.bananaGold, .bananaGoldDark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 8)
                .frame(maxWidth: 300)

                Text("\(cleanedCount) / \(appState.enabledTargets.count) targets")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Completion State

    private var completionView: some View {
        VStack(spacing: 20) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: isComplete)
            }

            VStack(spacing: 8) {
                Text("All Clean! 🎉")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("\(totalReclaimed.formattedBytes) of tracking data removed")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            // Results summary
            VStack(spacing: 4) {
                let successes = results.filter(\.success).count
                let failures = results.count - successes

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(successes) succeeded")
                            .font(.system(size: 12))
                    }

                    if failures > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("\(failures) failed")
                                .font(.system(size: 12))
                        }
                    }
                }
                .foregroundStyle(.secondary)
            }

            Text("BananaBlitz will continue cleaning on your chosen schedule.\nClick the 🍌 in your menu bar to manage.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Actions

    private func startCleaning() {
        isCleaning = true

        // Snapshot the workload on the main thread so the background task
        // never reads `@Published` state.
        let jobs = appState.snapshotCleaningJobs()

        DispatchQueue.global(qos: .userInitiated).async {
            var allResults: [CleaningResult] = []

            for (index, job) in jobs.enumerated() {
                DispatchQueue.main.async {
                    withAnimation {
                        currentTarget = job.target.name
                        progress = Double(index) / Double(jobs.count)
                        cleanedCount = index
                    }
                }

                let result = PrivacyCleaner.shared.clean(target: job.target, strategy: job.strategy)
                allResults.append(result)

                // Small delay for visual feedback
                Thread.sleep(forTimeInterval: 0.15)
            }

            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    results = allResults
                    totalReclaimed = allResults.reduce(0) { $0 + $1.bytesReclaimed }
                    cleanedCount = jobs.count
                    progress = 1.0
                    isCleaning = false
                    isComplete = true

                    // Record results
                    for result in allResults {
                        appState.addResult(result)
                    }
                }
            }
        }
    }
}
