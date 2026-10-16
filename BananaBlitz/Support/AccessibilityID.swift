import Foundation

/// Accessibility identifiers for every control the UI test suite drives.
///
/// This file is compiled into both the app and `BananaBlitzUITests`, so the
/// two can never drift. Identifiers are invisible to users; VoiceOver reads
/// labels, which the views set separately.
enum AccessibilityID {

    enum MenuBar {
        static let statusItem     = "menubar.statusItem"
        static let title          = "menubar.title"
        static let status         = "menubar.status"
        static let nextClean      = "menubar.nextClean"
        static let totalReclaimed = "menubar.totalReclaimed"
        static let blitzNow       = "menubar.blitzNow"
        static let outcome        = "menubar.outcome"
        static let outcomeDetails = "menubar.outcomeDetails"
        static let scheduleLabel  = "menubar.scheduleLabel"
        static let pauseResume    = "menubar.pauseResume"
        static let getStarted     = "menubar.getStarted"
        static let settings       = "menubar.settings"
        static let about          = "menubar.about"
        static let quit           = "menubar.quit"
        static func levelRow(_ level: String) -> String { "menubar.level.\(level)" }
    }

    enum Onboarding {
        static let stepIndicator      = "onboarding.stepIndicator"
        static let back               = "onboarding.back"
        static let next               = "onboarding.next"
        static let finish             = "onboarding.finish"
        static let skipPermission     = "onboarding.skipPermission"
        static let permissionTitle    = "onboarding.permissionTitle"
        static let openSystemSettings = "onboarding.openSystemSettings"
        static let scanTitle          = "onboarding.scanTitle"
        static let scanSummary        = "onboarding.scanSummary"
        static let scanAccessBanner   = "onboarding.scanAccessBanner"
        static let createSnapshot     = "onboarding.createSnapshot"
        static let levelSummary       = "onboarding.levelSummary"
        static let scheduleInterval   = "onboarding.scheduleInterval"
        static let launchAtLogin      = "onboarding.launchAtLogin"
        static let blitz              = "onboarding.blitz"
        static let readyTitle         = "onboarding.readyTitle"
        static let readySummary       = "onboarding.readySummary"
        static let completionTitle    = "onboarding.completionTitle"
        static let completionSummary  = "onboarding.completionSummary"
        static let completionBytes    = "onboarding.completionBytes"
        static func levelCard(_ level: String) -> String { "onboarding.level.\(level)" }
    }

    /// Settings panes. The window, its toolbar tabs, Launch at login, the
    /// About button and Reset come from the shared surface code and are
    /// found by their labels instead.
    enum Settings {
        static let recoveryStatus       = "settings.data.recoveryStatus"
        static let historyStatus        = "settings.data.historyStatus"
        static let scheduleInterval     = "settings.schedule.interval"
        static let pauseSchedule        = "settings.schedule.pause"
        static let nextClean            = "settings.schedule.nextClean"
        static let allowLocking         = "settings.schedule.allowLocking"
        static let defaultLevel         = "settings.schedule.level"
        static let levelDescription     = "settings.schedule.levelDescription"
        static let globalStrategy       = "settings.schedule.strategy"
        static let notificationStyle    = "settings.prefs.notifications"
        static let autoUpdate           = "settings.prefs.autoUpdate"
        static let checkForUpdates      = "settings.prefs.checkForUpdates"
        static let launchAtLogin        = "settings.prefs.launchAtLogin"
        static let menuBarStatus        = "settings.prefs.menuBarStatus"
        static let menuBarIcon          = "settings.prefs.menuBarIcon"
        static let keyboardShortcut     = "settings.prefs.keyboardShortcut"
        static let fullDiskAccessStatus = "settings.prefs.fdaStatus"
        static let openFullDiskAccess   = "settings.prefs.openFDA"
        static let rescan               = "settings.data.rescan"
        static let selfTest             = "settings.data.selfTest"
        static let dryRun               = "settings.data.dryRun"
        static let saveRecoveryScript   = "settings.data.saveRecoveryScript"
        static let exportHistory        = "settings.data.exportHistory"
        static let createSnapshot       = "settings.data.createSnapshot"
        static let dataStatus           = "settings.data.status"
        static let reset                = "settings.data.reset"
        static let about                = "settings.about"
    }

    enum Targets {
        static let search = "targets.search"
        static let filter = "targets.filter"
        static func sectionToggleAll(_ level: String) -> String { "targets.section.\(level).toggleAll" }
        static func row(_ id: String) -> String { "targets.row.\(id)" }
        static func toggle(_ id: String) -> String { "targets.toggle.\(id)" }
        static func strategy(_ id: String) -> String { "targets.strategy.\(id)" }
        static func verify(_ id: String) -> String { "targets.verify.\(id)" }
        static func unlock(_ id: String) -> String { "targets.unlock.\(id)" }
        static func size(_ id: String) -> String { "targets.size.\(id)" }
    }

    enum DryRun {
        static let title          = "dryRun.title"
        static let close          = "dryRun.close"
        static let cancel         = "dryRun.cancel"
        static let confirm        = "dryRun.confirm"
        static let targetCount    = "dryRun.targetCount"
        static let itemCount      = "dryRun.itemCount"
        static let byteCount      = "dryRun.byteCount"
        static let empty          = "dryRun.empty"
        static let footerWarning  = "dryRun.footerWarning"
        static let saveRecovery   = "dryRun.saveRecovery"
        static let lockBadge      = "dryRun.lockBadge"
        static func row(_ id: String) -> String { "dryRun.row.\(id)" }
    }

    enum SelfTest {
        static let title   = "selfTest.title"
        static let close   = "selfTest.close"
        static let healthy = "selfTest.healthy"
        static let locked  = "selfTest.locked"
        static let denied  = "selfTest.denied"
        static func row(_ id: String) -> String { "selfTest.row.\(id)" }
    }

    enum Dashboard {
        static let totalReclaimed = "dashboard.totalReclaimed"
        static let targetsEnabled = "dashboard.targetsEnabled"
        static let lastClean      = "dashboard.lastClean"
        static let emptyHistory   = "dashboard.emptyHistory"
        static let failureBanner  = "dashboard.failureBanner"
        static func historyRow(_ id: String) -> String { "dashboard.history.\(id)" }
    }

    enum About {
        static let version     = "about.version"
        static let provenance  = "about.provenance"
        static let copyReport  = "about.copyReport"
        static let github      = "about.github"
        static let reportIssue = "about.reportIssue"
    }
}
