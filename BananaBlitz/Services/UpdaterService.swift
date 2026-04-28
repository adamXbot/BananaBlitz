import Foundation
import Sparkle
import AppKit

/// Thin wrapper around Sparkle's standard updater controller.
///
/// Exposes Sparkle's auto-check preferences as `@Published` properties so
/// they can drive a SwiftUI Settings UI without each setting needing a
/// hand-rolled `@AppStorage` mirror. (Sparkle persists the underlying
/// values to `UserDefaults` itself under its own key namespace.)
///
/// To enable updates, you need three things:
///   1. A Developer ID-signed and notarized app (so Sparkle can verify the
///      installer).
///   2. An EdDSA key pair generated with `generate_keys` from the Sparkle
///      tools (`brew install --cask sparkle`). The public key goes in
///      `Info.plist` under `SUPublicEDKey`.
///   3. An appcast.xml hosted at a stable URL, with `SUFeedURL` in
///      `Info.plist` pointing to it.
///
/// Until those are in place, `canCheckForUpdates` returns false and the
/// "Check for Updates" command / button disables itself.
@MainActor
final class UpdaterService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var canCheckForUpdates: Bool = false

    /// User-visible toggle: should Sparkle silently check on a timer?
    /// Even when off, the user can still trigger manual checks from the
    /// app menu or Settings.
    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            let value = automaticallyChecksForUpdates
            controller.updater.automaticallyChecksForUpdates = value
            log.debug("automaticallyChecksForUpdates = \(value)")
        }
    }

    /// Auto-check cadence in seconds. Sparkle treats values < 3600 as a
    /// debug shortcut, so the Settings UI restricts this to daily/weekly/monthly.
    @Published var updateCheckInterval: TimeInterval {
        didSet {
            let value = updateCheckInterval
            controller.updater.updateCheckInterval = value
            log.debug("updateCheckInterval = \(value)s")
        }
    }

    @Published private(set) var lastUpdateCheckDate: Date?

    // MARK: - Private

    private let controller: SPUStandardUpdaterController
    private let log = AppLog.app

    // MARK: - Init

    init() {
        // `startingUpdater: false` so we don't fire a background check before
        // the feed URL is verified. We start manually below.
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller = controller

        // Seed @Published state from whatever Sparkle has persisted.
        self.automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        self.updateCheckInterval = controller.updater.updateCheckInterval
        self.lastUpdateCheckDate = controller.updater.lastUpdateCheckDate

        let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        if let feedURL = feedURL, !feedURL.isEmpty {
            do {
                try controller.updater.start()
                canCheckForUpdates = true
                log.info("Sparkle updater started with feed: \(feedURL, privacy: .public)")
            } catch {
                log.error("Sparkle updater failed to start: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            log.debug("Sparkle updater is dormant: no SUFeedURL configured")
        }
    }

    // MARK: - Actions

    /// User-initiated "Check for Updates…" entry point.
    func checkForUpdates() {
        guard canCheckForUpdates else {
            log.error("checkForUpdates invoked while updater is not configured")
            return
        }
        controller.checkForUpdates(nil)
        // Sparkle updates lastUpdateCheckDate asynchronously; refresh after a tick.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            self.lastUpdateCheckDate = self.controller.updater.lastUpdateCheckDate
        }
    }
}
