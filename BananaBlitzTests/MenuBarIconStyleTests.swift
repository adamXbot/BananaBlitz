import XCTest
@testable import BananaBlitz

/// The menu bar icon is stored by the shared `SurfaceMenuBarPreference`;
/// these cover the one-time move from the key older builds used.
@MainActor
final class MenuBarIconStyleTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "MenuBarIconStyleTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    private func preference() -> SurfaceMenuBarPreference {
        SurfaceMenuBarPreference(defaultIcon: MenuBarIconStyle.default.rawValue, defaults: defaults)
    }

    func test_default_isMonochromeBanana() {
        MenuBarIconStyle.migrateLegacyPreference(in: defaults)
        XCTAssertEqual(MenuBarIconStyle(rawValue: preference().icon), .bananaMono)
    }

    func test_legacyValue_movesToTheSharedKeyOnce() {
        defaults.set(MenuBarIconStyle.sparkles.rawValue, forKey: StorageKey.menuBarIconStyleRaw)

        MenuBarIconStyle.migrateLegacyPreference(in: defaults)

        XCTAssertEqual(MenuBarIconStyle(rawValue: preference().icon), .sparkles)
        XCTAssertEqual(defaults.string(forKey: MenuBarIconStyle.preferenceKey), MenuBarIconStyle.sparkles.rawValue)
        XCTAssertNil(defaults.object(forKey: StorageKey.menuBarIconStyleRaw), "the legacy key is removed")
    }

    func test_legacyValue_neverOverridesAnExistingChoice() {
        defaults.set(MenuBarIconStyle.banana.rawValue, forKey: MenuBarIconStyle.preferenceKey)
        defaults.set(MenuBarIconStyle.sparkles.rawValue, forKey: StorageKey.menuBarIconStyleRaw)

        MenuBarIconStyle.migrateLegacyPreference(in: defaults)

        XCTAssertEqual(MenuBarIconStyle(rawValue: preference().icon), .banana)
        XCTAssertNil(defaults.object(forKey: StorageKey.menuBarIconStyleRaw))
    }

    func test_unknownLegacyValue_fallsBackToTheDefault() {
        defaults.set("not-a-real-style", forKey: StorageKey.menuBarIconStyleRaw)

        MenuBarIconStyle.migrateLegacyPreference(in: defaults)

        XCTAssertEqual(MenuBarIconStyle(rawValue: preference().icon), .bananaMono)
        XCTAssertNil(defaults.object(forKey: StorageKey.menuBarIconStyleRaw))
    }

    func test_preferenceKey_matchesTheSharedDefaultPrefix() {
        let preference = preference()
        preference.setIcon(MenuBarIconStyle.sparkles.rawValue)
        XCTAssertEqual(defaults.string(forKey: MenuBarIconStyle.preferenceKey), MenuBarIconStyle.sparkles.rawValue)
    }

    func test_everyStyle_hasATitleForThePicker() {
        for style in MenuBarIconStyle.allCases {
            XCTAssertFalse(style.displayName.isEmpty, "\(style) needs a picker title")
        }
    }
}
