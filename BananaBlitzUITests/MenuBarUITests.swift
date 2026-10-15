import XCTest

/// The menu bar popover in its steady state: status, the dashboard tiles,
/// pause/resume, the confirm-then-clean flow against sandboxed fixtures, and
/// the shared footer.
final class MenuBarUITests: BananaBlitzUITestCase {

    func test_popoverSummarisesStateAndTargets() throws {
        try sandbox.grantFullDiskAccess()
        try launchApp()
        openMenuBarPopover()

        waitForLabel(element(AccessibilityID.MenuBar.status), toContain: "Never cleaned")
        waitForLabel(element(AccessibilityID.Dashboard.totalReclaimed), toContain: "Zero KB")
        waitForLabel(element(AccessibilityID.Dashboard.targetsEnabled), toContain: "18/26")
        waitForLabel(element(AccessibilityID.Dashboard.lastClean), toContain: "Never")
        waitFor(element(AccessibilityID.Dashboard.emptyHistory))
        waitForLabel(element(AccessibilityID.MenuBar.scheduleLabel), toContain: "Every 4 hours")
        waitForLabel(element(AccessibilityID.MenuBar.nextClean), toContain: "Next clean in")
        // Default level is Strong: basic + strong on, paranoid off.
        waitForLabel(element(AccessibilityID.MenuBar.levelRow("basic")), toContain: "8/8")
        waitForLabel(element(AccessibilityID.MenuBar.levelRow("strong")), toContain: "10/10")
        waitForLabel(element(AccessibilityID.MenuBar.levelRow("paranoid")), toContain: "0/8")
        waitForLabel(element(AccessibilityID.MenuBar.pauseResume), toContain: "Pause")
        saveScreenshot("menubar-popover", of: popoverWindow)
    }

    func test_pauseAndResumeSchedule() throws {
        try launchApp()
        openMenuBarPopover()

        let pause = element(AccessibilityID.MenuBar.pauseResume)
        pause.click()
        waitForLabel(pause, toContain: "Resume")
        waitUntilGone(element(AccessibilityID.MenuBar.nextClean))
        saveScreenshot("menubar-paused", of: popoverWindow)

        pause.click()
        waitForLabel(pause, toContain: "Pause")
        waitFor(element(AccessibilityID.MenuBar.nextClean))
    }

    func test_blitzNowPreviewsThenCleansOnlyAfterConfirmation() throws {
        try sandbox.grantFullDiskAccess()
        for fixture in Fixture.basic + [.biome] { try sandbox.populate(fixture) } // 5 × 3 KB

        try launchApp()
        openMenuBarPopover()
        element(AccessibilityID.MenuBar.blitzNow).click()

        waitFor(confirmWindow)
        waitForLabel(element(AccessibilityID.DryRun.title), toContain: "Confirm Blitz")
        waitForLabel(element(AccessibilityID.DryRun.targetCount), toContain: "18")
        waitForLabel(element(AccessibilityID.DryRun.itemCount), toContain: "15")
        waitForLabel(element(AccessibilityID.DryRun.byteCount), toContain: "15 KB")
        waitForLabel(element(AccessibilityID.DryRun.footerWarning), toContain: "Nothing is locked")
        XCTAssertFalse(element(AccessibilityID.DryRun.saveRecovery).exists, "no recovery prompt without a lock")
        saveScreenshot("menubar-confirm-blitz", of: confirmWindow)

        // Cancelling touches nothing.
        element(AccessibilityID.DryRun.cancel).click()
        waitUntilGone(confirmWindow)
        XCTAssertEqual(sandbox.contents(of: .biome).count, 3)

        reopenPopoverAfterSheetDismissal()
        element(AccessibilityID.MenuBar.blitzNow).click()
        waitFor(element(AccessibilityID.DryRun.confirm)).click()

        // Confirming closes the window; the popover closed when the window
        // opened, and shows the result the next time it opens.
        reopenPopoverAfterSheetDismissal()
        let outcome = element(AccessibilityID.MenuBar.outcome)
        waitForLabel(outcome, toContain: "Cleaned 18", timeout: 30)
        waitForLabel(outcome, toContain: "15 KB reclaimed")
        waitForLabel(element(AccessibilityID.MenuBar.status), toContain: "Cleaned just now")
        waitForLabel(element(AccessibilityID.Dashboard.totalReclaimed), toContain: "15 KB")
        waitForLabel(element(AccessibilityID.Dashboard.lastClean), toContain: "Just now")
        // The popover's recent-activity list is now populated.
        waitUntilGone(element(AccessibilityID.Dashboard.emptyHistory))
        XCTAssertFalse(element(AccessibilityID.Dashboard.failureBanner).exists)
        // The cached sizes are refreshed after the clean, so the level rows
        // stop showing the bytes that were just removed.
        waitForLabel(element(AccessibilityID.MenuBar.levelRow("basic")), toNotContain: "KB")
        waitForLabel(element(AccessibilityID.MenuBar.levelRow("strong")), toNotContain: "KB")
        saveScreenshot("menubar-after-blitz", of: popoverWindow)

        for fixture in Fixture.basic + [.biome] {
            XCTAssertEqual(sandbox.contents(of: fixture), [], "\(fixture.id) should be emptied")
        }
    }

    /// Regression: the confirmation used to be a sheet on the popover. The
    /// first click inside it closed the popover (so Blitz Now never ran) and
    /// the sheet came straight back on the next open with "Blitz Now" as the
    /// default button, so a stray Return could start a clean.
    func test_cancelledConfirmationDoesNotReturnWhenThePopoverReopens() throws {
        try sandbox.grantFullDiskAccess()
        try sandbox.populate(.adPrivacy)
        try launchApp()
        openMenuBarPopover()
        element(AccessibilityID.MenuBar.blitzNow).click()
        waitFor(confirmWindow)
        element(AccessibilityID.DryRun.cancel).click()
        waitUntilGone(confirmWindow)

        reopenPopoverAfterSheetDismissal()
        Thread.sleep(forTimeInterval: 2) // give a ghost confirmation time to re-present
        XCTAssertFalse(confirmWindow.exists, "the cancelled confirmation came back on its own")
        XCTAssertTrue(element(AccessibilityID.MenuBar.blitzNow).isHittable)
        XCTAssertEqual(sandbox.contents(of: .adPrivacy).count, 3, "nothing was cleaned")
    }

    /// Regression: bootstrap ran from the popover's `onAppear`, which fires
    /// on every open, so each open re-armed the schedule timer and the next
    /// clean kept moving into the future. The countdown must keep counting.
    func test_reopeningThePopoverDoesNotResetTheSchedule() throws {
        try launchApp()
        openMenuBarPopover()
        let next = element(AccessibilityID.MenuBar.nextClean)
        waitForLabel(next, toContain: "in 3h 59m")
        closeMenuBarPopover()

        Thread.sleep(forTimeInterval: 65)

        openMenuBarPopover()
        waitForLabel(next, toContain: "in 3h 58m")
    }

    func test_footerOpensSettingsAndQuits() throws {
        try launchApp()
        let settings = openSettings()
        closeWindow(settings)

        openMenuBarPopover()
        popoverAnchor.click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: uiTimeout))
    }
}
