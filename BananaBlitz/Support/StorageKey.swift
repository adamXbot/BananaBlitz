import Foundation

/// Centralised AppStorage keys to avoid drift on rename.
enum StorageKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let onboardingStep         = "onboardingStep"
    static let selectedLevelRaw       = "selectedLevelRaw"
    static let scheduleIntervalRaw    = "scheduleIntervalRaw"
    static let notificationStyleRaw   = "notificationStyleRaw"
    static let isPaused               = "isPaused"
    static let showMenuBarStatus      = "showMenuBarStatus"
    /// Legacy: builds before the shared surfaces stored the menu bar icon
    /// here. Read once by `MenuBarIconStyle.migrateLegacyPreference` and
    /// then removed; the icon now lives under `MenuBarIconStyle.preferenceKey`.
    static let menuBarIconStyleRaw    = "menuBarIconStyleRaw"
    static let enableKeyboardShortcut = "enableKeyboardShortcut"
    static let globalStrategyRaw      = "globalStrategyRaw"
    static let allowAggressiveScheduledClean = "allowAggressiveScheduledClean"
}
