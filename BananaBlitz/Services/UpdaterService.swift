import Foundation
import Sparkle

/// Owns Sparkle's standard updater controller and starts it only when the
/// app is configured for updates. The Updates pane and the Check for
/// Updates… item are driven by `SurfaceUpdates`, which reads and writes the
/// updater directly; this class exists so the controller outlives any view.
///
/// To enable updates, you need three things:
///   1. A Developer ID-signed and notarised app (so Sparkle can verify the
///      installer).
///   2. An EdDSA key pair generated with `generate_keys` from the Sparkle
///      tools (`brew install --cask sparkle`). The public key goes in
///      `Info.plist` under `SUPublicEDKey`.
///   3. An appcast.xml hosted at a stable URL, with `SUFeedURL` in
///      `Info.plist` pointing to it.
///
/// Until those are in place the updater stays dormant: Sparkle logs and
/// ignores a check, and `SPUUpdater.canCheckForUpdates` stays false.
@MainActor
final class UpdaterService {
    private let controller: SPUStandardUpdaterController
    private let log = AppLog.app

    /// The updater the shared Updates pane drives.
    var updater: SPUUpdater { controller.updater }

    init() {
        // `startingUpdater: false` so no background check fires before the
        // feed URL is verified. Automatic checks are off until the user turns
        // them on in Settings (`SUEnableAutomaticChecks` is false in Info.plist).
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        if let feedURL, !feedURL.isEmpty {
            do {
                try controller.updater.start()
                log.info("Sparkle updater started with feed: \(feedURL, privacy: .public)")
            } catch {
                log.error("Sparkle updater failed to start: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            log.debug("Sparkle updater is dormant: no SUFeedURL configured")
        }
    }
}
