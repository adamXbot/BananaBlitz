import AppKit
import Foundation

/// Process-level switches used only by the UI test suite (`BananaBlitzUITests`).
///
/// Every hook is gated on the `--ui-testing` launch argument, so a normal
/// launch is unaffected. In UI-testing mode the app:
///   * reads and writes preferences in a dedicated `UserDefaults` suite that is
///     wiped at launch, so a test run never touches the real app's preferences;
///   * refuses to start unless its home directory has been redirected to a
///     throwaway sandbox (the test sets `CFFIXED_USER_HOME`), so a test can
///     never scan, clean or lock anything in the real `~/Library`;
///   * seeds preferences from `BB_UITEST_DEFAULTS` (a JSON object) so a test can
///     start from "onboarding complete" without clicking through the wizard;
///   * forces light or dark appearance from `BB_UITEST_APPEARANCE`;
///   * skips the notification-permission prompt, which would block a test.
enum LaunchConfiguration {
    static let uiTestingArgument = "--ui-testing"
    static let defaultsSuiteName = "com.bananablitz.uitests"

    /// Environment variables the UI test runner sets on the app process.
    enum EnvironmentKey {
        /// Must equal `NSHomeDirectory()`. The runner sets this *and*
        /// `CFFIXED_USER_HOME` to the same sandbox path; the app cross-checks.
        static let sandboxHome = "BB_UITEST_HOME"
        /// JSON object of preference key → value, applied after the suite is wiped.
        static let seedDefaults = "BB_UITEST_DEFAULTS"
        /// `"light"` or `"dark"`.
        static let appearance = "BB_UITEST_APPEARANCE"
        /// `"1"` keeps the preference suite from the previous launch (relaunch tests).
        static let preserveState = "BB_UITEST_PRESERVE_STATE"
    }

    static let isUITesting: Bool = ProcessInfo.processInfo.arguments.contains(uiTestingArgument)

    /// The store behind every `@AppStorage` in the app. `.standard` unless the
    /// app was launched by the UI test suite.
    static let defaults: UserDefaults = {
        guard isUITesting, let suite = UserDefaults(suiteName: defaultsSuiteName) else {
            return .standard
        }
        return suite
    }()

    /// Must run before any `AppState` is created. No-op outside UI testing.
    static func applyIfNeeded() {
        guard isUITesting else { return }
        let environment = ProcessInfo.processInfo.environment
        verifySandboxedHome(environment)
        if environment[EnvironmentKey.preserveState] != "1" {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
            seedDefaults(from: environment[EnvironmentKey.seedDefaults])
        }
        applyAppearance(environment[EnvironmentKey.appearance])
    }

    /// Hard stop rather than a warning: a UI test that ran against the real
    /// home directory would delete the user's own `~/Library` data.
    private static func verifySandboxedHome(_ environment: [String: String]) {
        let home = (NSHomeDirectory() as NSString).standardizingPath
        guard let expected = environment[EnvironmentKey.sandboxHome], !expected.isEmpty,
              home == (expected as NSString).standardizingPath,
              home.contains("bananablitz-uitest") else {
            fatalError("Refusing to run in UI-testing mode: home directory \(home) is not a BananaBlitz test sandbox.")
        }
    }

    private static func seedDefaults(from json: String?) {
        guard let json, let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        for (key, value) in object {
            defaults.set(value, forKey: key)
        }
    }

    private static func applyAppearance(_ name: String?) {
        switch name {
        case "dark":  NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApplication.shared.appearance = NSAppearance(named: .aqua)
        default:      break
        }
    }
}
