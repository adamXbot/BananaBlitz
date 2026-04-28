import SwiftUI
import AppKit

/// "About BananaBlitz" panel.
///
/// Layout mirrors the privacycommand About pane: app icon → wordmark →
/// version + build → one-line tagline → capability grid → action links
/// (Check for Updates, GitHub, Report Issue) with the repo URL displayed
/// monospace beneath the GitHub link. Reachable from the menu bar footer
/// and from Settings → About.
struct AboutView: View {
    private let version: String = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    private let build:   String = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"

    /// Optional commit SHA injected at build time via a custom Info.plist key.
    /// Add `BBCommitSHA = $(BB_COMMIT_SHA)` and a build-phase script to populate.
    private var commitSHA: String? {
        guard let raw = Bundle.main.infoDictionary?["BBCommitSHA"] as? String,
              !raw.isEmpty else { return nil }
        return String(raw.prefix(8))
    }

    private static let repoURL = URL(string: "https://github.com/adamXbot/BananaBlitz")!
    private static let issueURL = URL(string: "https://github.com/adamXbot/BananaBlitz/issues/new")!

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 128, height: 128)
                }

                BananaWordmarkView(fontSize: 44)

                Text("Version \(version) (\(build))")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let sha = commitSHA {
                    Text("Commit \(sha)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }

                Text("Reclaim your privacy by clearing deep telemetry, intelligence, and tracking caches in ~/Library — without disabling SIP.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundStyle(.secondary)

                Divider().padding(.horizontal, 60)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 20, alignment: .topLeading),
                        GridItem(.flexible(), spacing: 20, alignment: .topLeading)
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    capability("Privacy levels", "Basic, Strong, and Paranoid presets that pre-select the right targets.")
                    capability("Smart directory locking", "Replace tracking dirs with immutable empty files via UF_IMMUTABLE.")
                    capability("Scheduled cleaning", "Hourly, daily, or on demand — with sleep / wake catch-up.")
                    capability("Recovery script", "One-click export of unbrick.sh tailored to your target list.")
                }
                .padding(.horizontal, 28)

                Divider().padding(.horizontal, 60)

                actionLinks

                Spacer(minLength: 8)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .frame(width: 540, height: 520)
    }

    // MARK: - Action Links

    @ViewBuilder
    private var actionLinks: some View {
        VStack(spacing: 8) {
            Link(destination: Self.repoURL) {
                HStack(spacing: 8) {
                    Image("GitHub")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    Text("Source on GitHub")
                    Image(systemName: "arrow.up.forward.square")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
            Text(Self.repoURL.absoluteString)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)

            Link(destination: Self.issueURL) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.bubble")
                    Text("Report an Issue")
                    Image(systemName: "arrow.up.forward.square")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }

            Text("MIT License · © 2026")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
    }

    // MARK: - Capability Cell

    private func capability(_ title: String, _ desc: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.bold())
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Wordmark

/// SwiftUI rendering of the BananaBlitz wordmark — `Banana` in regular
/// weight using primary text color, `Blitz` in medium weight filled with
/// the banana-gold gradient (matches `Color.bananaGold` / `bananaGoldDark`
/// used throughout the rest of the app).
///
/// Mirrors the structure of privacycommand's `WordmarkView` so the About
/// pane in both apps reads as part of the same family.
struct BananaWordmarkView: View {
    var fontSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 4) {
            Text("🍌")
                .font(.system(size: fontSize * 0.85))

            HStack(spacing: 0) {
                Text("Banana")
                    .fontWeight(.regular)
                    .foregroundStyle(.primary)
                Text("Blitz")
                    .fontWeight(.medium)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.bananaGold, .bananaGoldDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .font(.system(size: fontSize))
            .kerning(-fontSize * 0.025)
        }
        .accessibilityLabel("BananaBlitz")
    }
}

#Preview("Wordmark") {
    VStack(spacing: 24) {
        BananaWordmarkView(fontSize: 32)
        BananaWordmarkView(fontSize: 44)
        BananaWordmarkView(fontSize: 64)
    }
    .padding(40)
}

#Preview("About") {
    AboutView()
}
