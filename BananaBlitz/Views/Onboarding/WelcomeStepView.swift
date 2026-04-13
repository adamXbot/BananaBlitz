import SwiftUI

/// Step 1: Welcome hero screen introducing BananaBlitz.
struct WelcomeStepView: View {
    @State private var bananaOffset: CGFloat = -20
    @State private var bananaOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var featuresOpacity: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Hero banana
            Text("🍌")
                .font(.system(size: 80))
                .offset(y: bananaOffset)
                .opacity(bananaOpacity)
                .onAppear {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                        bananaOffset = 0
                        bananaOpacity = 1
                    }
                }

            // Title
            VStack(spacing: 8) {
                Text("BananaBlitz")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("Take back your privacy")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .opacity(textOpacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.6).delay(0.5)) {
                    textOpacity = 1
                }
            }

            // Feature bullets
            VStack(alignment: .leading, spacing: 16) {
                featureRow(
                    icon: "shield.checkered",
                    color: .green,
                    title: "Clean tracking databases",
                    subtitle: "Remove telemetry, analytics, and profiling data from ~/Library"
                )

                featureRow(
                    icon: "lock.fill",
                    color: .orange,
                    title: "Lock out data collectors",
                    subtitle: "Replace folders with immutable files so daemons can't rebuild"
                )

                featureRow(
                    icon: "clock.fill",
                    color: .blue,
                    title: "Automated scheduling",
                    subtitle: "Set it and forget it — clean every hour, day, or on demand"
                )
            }
            .padding(.horizontal, 40)
            .opacity(featuresOpacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.6).delay(0.8)) {
                    featuresOpacity = 1
                }
            }

            Spacer()

            // Disclaimer
            Text("BananaBlitz operates without disabling System Integrity Protection.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
        }
        .padding(24)
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
