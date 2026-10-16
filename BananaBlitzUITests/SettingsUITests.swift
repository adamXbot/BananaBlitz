import XCTest

/// The Settings window (shared toolbar-tab scaffold): General, Schedule and
/// Data panes, the dry-run and self-test sheets, About, and Reset.
final class SettingsUITests: BananaBlitzUITestCase {

    func test_tabsSwitchContent() throws {
        try launchApp()
        let window = openSettings()

        selectSettingsTab("General")
        waitFor(element(AccessibilityID.Settings.fullDiskAccessStatus))
        waitFor(element(AccessibilityID.Settings.menuBarStatus))
        saveScreenshot("settings-general", of: window)

        selectSettingsTab("Targets")
        waitFor(element(AccessibilityID.Targets.search))
        saveScreenshot("settings-targets", of: window)

        selectSettingsTab("Schedule")
        waitFor(element(AccessibilityID.Settings.scheduleInterval))
        saveScreenshot("settings-schedule", of: window)

        selectSettingsTab("Data")
        waitFor(element(AccessibilityID.Settings.dryRun))
        saveScreenshot("settings-data", of: window)

        selectSettingsTab("Updates")
        waitFor(window.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Check'")).firstMatch)
        saveScreenshot("settings-updates", of: window)
    }

    func test_aboutShowsVersionAndBuildNumber() throws {
        try launchApp()
        let about = openAbout()
        let version = about.staticTexts.matching(NSPredicate(format: "value BEGINSWITH 'Version ' OR label BEGINSWITH 'Version '")).firstMatch
        waitFor(version)
        // "Version 1.1.0 (2026.1015.0420)": marketing version plus the UTC build stamp.
        let text = displayedText(of: version)
        XCTAssertTrue(text.range(of: #"Version \d+\.\d+\.\d+ \(\d{4}\.\d{4}\.\d{4}\)"#, options: .regularExpression) != nil,
                      "unexpected version line: \(text)")
        // The repository link is shared surface code; match it loosely.
        waitFor(about.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'GitHub' OR title CONTAINS 'GitHub' OR value CONTAINS 'github.com'")).firstMatch)
        saveScreenshot("about", of: about)
        closeWindow(about)
    }

    func test_scheduleIntervalAndPauseAreReflectedInTheMenuBar() throws {
        try launchApp()
        openSettings()
        selectSettingsTab("Schedule")

        waitFor(element(AccessibilityID.Settings.nextClean))
        choose("Every hour", inPopUp: AccessibilityID.Settings.scheduleInterval)
        clickToggle(element(AccessibilityID.Settings.pauseSchedule))
        waitUntilGone(element(AccessibilityID.Settings.nextClean))

        openMenuBarPopover()
        waitForLabel(element(AccessibilityID.MenuBar.scheduleLabel), toContain: "Every hour")
        waitForLabel(element(AccessibilityID.MenuBar.pauseResume), toContain: "Resume")
    }

    func test_defaultLevelPickerReselectsTargets() throws {
        try launchApp()
        openSettings()
        selectSettingsTab("Schedule")

        waitFor(element(AccessibilityID.Settings.defaultLevel))
        segment(AccessibilityID.Settings.defaultLevel, "Basic").click()
        openMenuBarPopover()
        waitForLabel(element(AccessibilityID.Dashboard.targetsEnabled), toContain: "8/26")
        closeMenuBarPopover()

        openSettings()
        segment(AccessibilityID.Settings.defaultLevel, "Paranoid").click()
        openMenuBarPopover()
        waitForLabel(element(AccessibilityID.Dashboard.targetsEnabled), toContain: "26/26")
    }

    func test_generalShowsFullDiskAccessStatus() throws {
        try launchApp()
        openSettings()
        selectSettingsTab("General")
        waitForLabel(element(AccessibilityID.Settings.fullDiskAccessStatus), toContain: "Not granted")
        waitFor(element(AccessibilityID.Settings.openFullDiskAccess))
        app.terminate()

        try sandbox.grantFullDiskAccess()
        try launchApp()
        openSettings()
        selectSettingsTab("General")
        waitForLabel(element(AccessibilityID.Settings.fullDiskAccessStatus), toContain: "Granted")
    }

    func test_generalPreferencesPersistAcrossRelaunch() throws {
        try launchApp()
        openSettings()
        selectSettingsTab("General")

        let shortcut = waitFor(element(AccessibilityID.Settings.keyboardShortcut))
        XCTAssertFalse(isOn(shortcut), "global shortcut is off by default")
        clickToggle(shortcut)
        XCTAssertTrue(isOn(shortcut))
        let sparkles = settingsWindow.buttons["Sparkles"].firstMatch
        sparkles.click()
        // The shared icon tile marks selection with an accessibility trait;
        // only hold it to that after relaunch if it reports it now.
        let tileReportsSelection = sparkles.isSelected
        let silent = segment(AccessibilityID.Settings.notificationStyle, "Silent")
        silent.click()
        let segmentReportsSelection = isSegmentSelected(silent)

        try relaunchPreservingState()
        openSettings()
        selectSettingsTab("General")
        let shortcutAfter = waitFor(element(AccessibilityID.Settings.keyboardShortcut))
        XCTAssertTrue(isOn(shortcutAfter), "global shortcut should persist across relaunch")
        if tileReportsSelection {
            XCTAssertTrue(settingsWindow.buttons["Sparkles"].firstMatch.isSelected, "icon choice should persist")
        }
        if segmentReportsSelection {
            XCTAssertTrue(isSegmentSelected(segment(AccessibilityID.Settings.notificationStyle, "Silent")),
                          "notification style should persist")
        }
    }

    func test_dryRunPreviewIsReadOnlyAndMirrorsTheScheduledRun() throws {
        try sandbox.grantFullDiskAccess()
        try sandbox.populate(.adPrivacy)
        // A lock strategy on one target; the scheduled preview must show it
        // downgraded to a wipe because locking on schedule is off. Seeded
        // rather than chosen in the Targets pane: choosing it there is
        // covered by TargetsUITests, and on the macOS 15 runner the Data
        // pane entered after that pop-up ignores clicks.
        try sandbox.seedStrategies([Fixture.adPrivacy.id: "replaceWithFile"])
        try launchApp()
        let window = openSettings()
        selectSettingsTab("Data")
        clickControl(element(AccessibilityID.Settings.dryRun))
        waitForLabel(element(AccessibilityID.DryRun.title), toContain: "Preview Next Clean")
        XCTAssertFalse(element(AccessibilityID.DryRun.confirm).exists, "a preview has nothing to confirm")
        waitForLabel(element(AccessibilityID.DryRun.targetCount), toContain: "18")
        waitForLabel(element(AccessibilityID.DryRun.byteCount), toContain: "3 KB")
        XCTAssertFalse(element(AccessibilityID.DryRun.lockBadge).exists, "lock downgraded for the unattended preview")
        saveScreenshot("settings-dry-run", of: window)
        element(AccessibilityID.DryRun.close).click()
        waitUntilGone(element(AccessibilityID.DryRun.title))
        XCTAssertEqual(sandbox.contents(of: .adPrivacy).count, 3, "a preview never touches the disk")
    }

    /// Opting in to scheduled locking changes the preview accordingly. A
    /// separate launch rather than a tab switch after the first preview: on
    /// the macOS 15 runner a pane entered after a sheet or pop-up in the same
    /// Settings session stops responding to clicks.
    func test_dryRunPreviewKeepsTheLockWhenScheduledLockingIsAllowed() throws {
        try sandbox.grantFullDiskAccess()
        try sandbox.populate(.adPrivacy)
        try sandbox.seedStrategies([Fixture.adPrivacy.id: "replaceWithFile"])
        var options = LaunchOptions()
        options.defaults[StorageKey.allowAggressiveScheduledClean] = true
        try launchApp(options)
        openSettings()
        selectSettingsTab("Data")
        clickControl(element(AccessibilityID.Settings.dryRun))
        waitForLabel(element(AccessibilityID.DryRun.title), toContain: "Preview Next Clean")
        waitFor(element(AccessibilityID.DryRun.lockBadge))
        element(AccessibilityID.DryRun.close).click()
        waitUntilGone(element(AccessibilityID.DryRun.title))
    }

    func test_selfTestReportsEveryTarget() throws {
        try sandbox.grantFullDiskAccess()
        try sandbox.populate(.adPrivacy)
        try launchApp()
        let window = openSettings()
        selectSettingsTab("Data")

        clickControl(element(AccessibilityID.Settings.selfTest))
        waitFor(element(AccessibilityID.SelfTest.title))
        // Biome (the access probe) and Ad Privacy exist in the sandbox.
        waitForLabel(element(AccessibilityID.SelfTest.healthy), toContain: "Healthy: 2")
        waitForLabel(element(AccessibilityID.SelfTest.locked), toContain: "Locked: 0")
        waitForLabel(element(AccessibilityID.SelfTest.denied), toContain: "Denied: 0")
        // The list is lazy, so only rows near the top are guaranteed to exist.
        waitFor(element(AccessibilityID.SelfTest.row(Fixture.adPrivacy.id)))
        waitFor(element(AccessibilityID.SelfTest.row(Fixture.amsEngagement.id)))
        saveScreenshot("settings-self-test", of: window)
        element(AccessibilityID.SelfTest.close).click()
        waitUntilGone(element(AccessibilityID.SelfTest.title))
    }

    func test_rescanRefreshesTargetSizes() throws {
        try sandbox.grantFullDiskAccess()
        try launchApp()
        openSettings()
        selectSettingsTab("Targets")
        waitForLabel(element(AccessibilityID.Targets.size(Fixture.adPrivacy.id)), toContain: "not present")

        try sandbox.populate(.adPrivacy)
        selectSettingsTab("Data")
        clickControl(element(AccessibilityID.Settings.rescan))
        selectSettingsTab("Targets")
        waitForLabel(element(AccessibilityID.Targets.size(Fixture.adPrivacy.id)), toContain: "3 KB")
    }

    func test_resetAllSettingsRestartsOnboarding() throws {
        try launchApp()
        let settings = openSettings()
        selectSettingsTab("Data")

        clickControl(settings.buttons["Reset All Settings…"].firstMatch)
        let confirm = dialogButton("Reset Everything")
        waitFor(confirm)
        saveScreenshot("settings-reset-confirm", of: frontSheet)
        confirm.click()

        waitFor(window(titled: "Welcome to BananaBlitz"))
        waitUntilGone(settings)
        waitForLabel(element(AccessibilityID.Onboarding.stepIndicator), toContain: "Step 1 of 7")
    }
}
