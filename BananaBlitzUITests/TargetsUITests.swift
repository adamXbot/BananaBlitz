import XCTest

/// The Targets pane: search, level filter, per-target toggles and
/// strategies, section-wide toggles, persistence, and the destructive
/// lock → unlock round trip against a sandboxed directory.
final class TargetsUITests: BananaBlitzUITestCase {

    func test_searchAndLevelFiltersNarrowTheList() throws {
        try launchApp()
        openSettings()
        selectSettingsTab("Targets")

        let adPrivacy = element(AccessibilityID.Targets.row(Fixture.adPrivacy.id))
        let biome = element(AccessibilityID.Targets.row(Fixture.biome.id))
        waitFor(adPrivacy)
        waitFor(biome)

        let search = element(AccessibilityID.Targets.search)
        search.click()
        app.typeText("Biome")
        waitUntilGone(adPrivacy)
        waitFor(biome)

        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        waitFor(adPrivacy)

        choose("Basic", inPopUp: AccessibilityID.Targets.filter)
        waitUntilGone(biome)
        waitFor(adPrivacy)

        choose("Paranoid", inPopUp: AccessibilityID.Targets.filter)
        waitUntilGone(adPrivacy)
        waitFor(element(AccessibilityID.Targets.row(Fixture.keyboardProfiling.id)))

        choose("All levels", inPopUp: AccessibilityID.Targets.filter)
        waitFor(adPrivacy)
        waitFor(biome)
    }

    func test_toggleAndSectionToggleUpdateCountsAndPersist() throws {
        try launchApp()
        openSettings()
        selectSettingsTab("Targets")

        let toggle = waitFor(element(AccessibilityID.Targets.toggle(Fixture.adPrivacy.id)))
        XCTAssertTrue(isOn(toggle), "basic targets start enabled at Strong level")
        toggle.click()
        XCTAssertFalse(isOn(toggle))

        openMenuBarPopover()
        waitForLabel(element(AccessibilityID.Dashboard.targetsEnabled), toContain: "17/26")
        closeMenuBarPopover()

        openSettings()
        // The list is lazy; filter to the level so its header is on screen.
        choose("Paranoid", inPopUp: AccessibilityID.Targets.filter)
        waitFor(element(AccessibilityID.Targets.sectionToggleAll("paranoid"))).click()
        choose("All levels", inPopUp: AccessibilityID.Targets.filter)
        openMenuBarPopover()
        waitForLabel(element(AccessibilityID.Dashboard.targetsEnabled), toContain: "25/26")
        closeMenuBarPopover()

        try relaunchPreservingState()
        openMenuBarPopover()
        waitForLabel(element(AccessibilityID.Dashboard.targetsEnabled), toContain: "25/26")
        closeMenuBarPopover()
        openSettings()
        selectSettingsTab("Targets")
        XCTAssertFalse(isOn(waitFor(element(AccessibilityID.Targets.toggle(Fixture.adPrivacy.id)))))
    }

    func test_rowExpandsToShowStrategyAndState() throws {
        try sandbox.grantFullDiskAccess()
        try sandbox.populate(.knowledgeC)
        try launchApp()
        let window = openSettings()
        selectSettingsTab("Targets")

        let strategy = element(AccessibilityID.Targets.strategy(Fixture.knowledgeC.id))
        XCTAssertFalse(strategy.exists, "details are collapsed by default")
        waitForLabel(element(AccessibilityID.Targets.size(Fixture.knowledgeC.id)), toContain: "3 KB")

        element(AccessibilityID.Targets.row(Fixture.knowledgeC.id)).click()
        waitFor(strategy)
        waitForLabel(strategy, toContain: "Wipe Contents")
        waitFor(element(AccessibilityID.Targets.verify(Fixture.knowledgeC.id)))
        XCTAssertFalse(element(AccessibilityID.Targets.unlock(Fixture.knowledgeC.id)).exists, "no Unlock while unlocked")
        saveScreenshot("settings-target-expanded", of: window)

        choose("Delete Databases Only", inPopUp: AccessibilityID.Targets.strategy(Fixture.knowledgeC.id))
        waitForLabel(strategy, toContain: "Delete Databases Only")

        // The single-strategy file target explains itself instead of offering a picker.
        element(AccessibilityID.Targets.row(Fixture.keyboardProfiling.id)).click()
        waitFor(app.staticTexts["Strategy: Delete Databases Only (Only supported method)"])
    }

    func test_lockStrategyLocksThenUnlockRestoresTheDirectory() throws {
        try sandbox.grantFullDiskAccess()
        try sandbox.populate(.adPrivacy)
        try launchApp()
        openSettings()
        selectSettingsTab("Targets")

        element(AccessibilityID.Targets.row(Fixture.adPrivacy.id)).click()
        choose("Lock with Immutable File", inPopUp: AccessibilityID.Targets.strategy(Fixture.adPrivacy.id))

        // A manual blitz warns, offers the recovery script, then locks.
        openMenuBarPopover()
        element(AccessibilityID.MenuBar.blitzNow).click()
        waitFor(confirmWindow)
        waitFor(element(AccessibilityID.DryRun.lockBadge))
        waitForLabel(element(AccessibilityID.DryRun.footerWarning), toContain: "not recoverable")
        waitFor(element(AccessibilityID.DryRun.saveRecovery))
        saveScreenshot("menubar-confirm-lock", of: confirmWindow)
        element(AccessibilityID.DryRun.confirm).click()
        reopenPopoverAfterSheetDismissal()
        waitForLabel(element(AccessibilityID.MenuBar.outcome), toContain: "Cleaned 18", timeout: 30)
        XCTAssertTrue(sandbox.isLocked(.adPrivacy), "target should be replaced by an immutable file")

        // A second blitz leaves the lock alone and says so.
        element(AccessibilityID.MenuBar.blitzNow).click()
        waitFor(confirmWindow)
        waitFor(app.staticTexts["Already locked — the lock is re-applied, nothing is deleted"])
        element(AccessibilityID.DryRun.cancel).click()
        waitUntilGone(confirmWindow)

        // Unlock from the Targets pane restores an empty directory.
        openSettings()
        selectSettingsTab("Targets")
        waitFor(element(AccessibilityID.Targets.verify(Fixture.adPrivacy.id))).click()
        let unlock = waitFor(element(AccessibilityID.Targets.unlock(Fixture.adPrivacy.id)))
        saveScreenshot("settings-target-locked", of: settingsWindow)
        unlock.click()
        waitUntilGone(unlock)
        XCTAssertFalse(sandbox.isLocked(.adPrivacy))
        XCTAssertTrue(sandbox.exists(.adPrivacy))
        XCTAssertEqual(sandbox.contents(of: .adPrivacy), [])
    }
}
