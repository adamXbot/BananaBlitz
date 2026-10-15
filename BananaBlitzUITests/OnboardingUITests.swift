import XCTest

/// The first-run wizard, end to end: it opens by itself, every step renders,
/// the first blitz actually cleans the (sandboxed) targets, and quitting
/// half-way resumes on the same step.
final class OnboardingUITests: BananaBlitzUITestCase {

    private let windowTitle = "Welcome to BananaBlitz"

    func test_freshLaunchWalksEveryStepAndCleans() throws {
        try sandbox.grantFullDiskAccess()
        for fixture in Fixture.basic { try sandbox.populate(fixture) } // 4 × 3 × 1 KB

        var options = LaunchOptions()
        options.onboardingComplete = false
        try launchApp(options)

        let window = waitFor(window(titled: windowTitle))
        let step = element(AccessibilityID.Onboarding.stepIndicator)
        let next = element(AccessibilityID.Onboarding.next)

        // 1 — Welcome
        waitForLabel(step, toContain: "Step 1 of 7")
        XCTAssertFalse(element(AccessibilityID.Onboarding.back).exists, "no Back on the first step")
        saveScreenshot("onboarding-1-welcome", of: window)
        next.click()

        // 2 — Full Disk Access (granted via the sandbox probe)
        waitForLabel(step, toContain: "Step 2 of 7")
        waitForLabel(element(AccessibilityID.Onboarding.permissionTitle), toContain: "Granted")
        XCTAssertFalse(element(AccessibilityID.Onboarding.skipPermission).exists, "no Skip once access is granted")
        XCTAssertFalse(element(AccessibilityID.Onboarding.openSystemSettings).exists)
        saveScreenshot("onboarding-2-permission", of: window)

        // Back works and returns to the same place.
        element(AccessibilityID.Onboarding.back).click()
        waitForLabel(step, toContain: "Step 1 of 7")
        next.click()
        waitForLabel(step, toContain: "Step 2 of 7")
        next.click()

        // 3 — Scan
        waitForLabel(step, toContain: "Step 3 of 7")
        waitForLabel(element(AccessibilityID.Onboarding.scanTitle), toContain: "Scan Complete")
        waitForLabel(element(AccessibilityID.Onboarding.scanSummary), toContain: "Found 12 KB of tracking data across 4 targets")
        XCTAssertFalse(element(AccessibilityID.Onboarding.scanAccessBanner).exists, "no access banner when access is granted")
        waitUntilEnabled(next)
        saveScreenshot("onboarding-3-scan", of: window)
        next.click()

        // 4 — Snapshot (optional; never create one in a test)
        waitForLabel(step, toContain: "Step 4 of 7")
        waitFor(element(AccessibilityID.Onboarding.createSnapshot))
        saveScreenshot("onboarding-4-snapshot", of: window)
        next.click()

        // 5 — Level
        waitForLabel(step, toContain: "Step 5 of 7")
        let summary = element(AccessibilityID.Onboarding.levelSummary)
        waitForLabel(summary, toContain: "Strong level: 18 targets")
        element(AccessibilityID.Onboarding.levelCard("paranoid")).click()
        waitForLabel(summary, toContain: "Paranoid level: 26 targets")
        element(AccessibilityID.Onboarding.levelCard("basic")).click()
        waitForLabel(summary, toContain: "Basic level: 8 targets")
        saveScreenshot("onboarding-5-level", of: window)
        next.click()

        // 6 — Schedule
        waitForLabel(step, toContain: "Step 6 of 7")
        waitFor(element(AccessibilityID.Onboarding.scheduleInterval))
        saveScreenshot("onboarding-6-schedule", of: window)
        next.click()

        // 7 — First blitz, confirmed through the dry-run sheet
        waitForLabel(step, toContain: "Step 7 of 7")
        waitFor(element(AccessibilityID.Onboarding.readyTitle))
        waitForLabel(element(AccessibilityID.Onboarding.readySummary), toContain: "Will clean 8 targets · 12 KB estimated")
        saveScreenshot("onboarding-7-ready", of: window)

        element(AccessibilityID.Onboarding.blitz).click()
        waitForLabel(element(AccessibilityID.DryRun.title), toContain: "Confirm First Blitz")
        waitForLabel(element(AccessibilityID.DryRun.targetCount), toContain: "8")
        waitForLabel(element(AccessibilityID.DryRun.byteCount), toContain: "12 KB")
        waitFor(element(AccessibilityID.DryRun.row(Fixture.adPrivacy.id)))
        saveScreenshot("onboarding-7-confirm", of: window)
        element(AccessibilityID.DryRun.confirm).click()

        waitForLabel(element(AccessibilityID.Onboarding.completionTitle), toContain: "All Clean", timeout: 30)
        waitForLabel(element(AccessibilityID.Onboarding.completionBytes), toContain: "12 KB")
        waitForLabel(element(AccessibilityID.Onboarding.completionSummary), toContain: "8 succeeded")
        saveScreenshot("onboarding-7-complete", of: window)

        for fixture in Fixture.basic {
            XCTAssertTrue(sandbox.exists(fixture), "\(fixture.id) directory should be kept")
            XCTAssertEqual(sandbox.contents(of: fixture), [], "\(fixture.id) should be emptied")
        }

        let finish = element(AccessibilityID.Onboarding.finish)
        waitUntilEnabled(finish)
        finish.click()
        waitUntilGone(window)

        // Steady state is reflected in the menu bar.
        openMenuBarPopover()
        waitForLabel(element(AccessibilityID.MenuBar.status), toContain: "Cleaned")
        waitForLabel(element(AccessibilityID.Dashboard.totalReclaimed), toContain: "12 KB")
        waitForLabel(element(AccessibilityID.MenuBar.levelRow("basic")), toContain: "8/8")
        waitForLabel(element(AccessibilityID.MenuBar.levelRow("strong")), toContain: "0/10")
    }

    func test_withoutFullDiskAccess_userCanSkipAndIsToldScanIsIncomplete() throws {
        var options = LaunchOptions()
        options.onboardingComplete = false
        try launchApp(options)

        let window = waitFor(window(titled: windowTitle))
        let step = element(AccessibilityID.Onboarding.stepIndicator)
        let next = element(AccessibilityID.Onboarding.next)
        next.click()

        waitForLabel(step, toContain: "Step 2 of 7")
        waitForLabel(element(AccessibilityID.Onboarding.permissionTitle), toContain: "Required")
        waitFor(element(AccessibilityID.Onboarding.openSystemSettings))
        XCTAssertFalse(next.isEnabled, "Continue must wait for access")
        waitForLabel(next, toContain: "Waiting")
        saveScreenshot("onboarding-2-permission-missing", of: window)

        waitFor(element(AccessibilityID.Onboarding.skipPermission)).click()

        waitForLabel(step, toContain: "Step 3 of 7")
        waitForLabel(element(AccessibilityID.Onboarding.scanTitle), toContain: "Scan Complete")
        waitFor(element(AccessibilityID.Onboarding.scanAccessBanner))
        saveScreenshot("onboarding-3-scan-no-access", of: window)

        // The rest of the wizard still completes without a clean.
        waitUntilEnabled(next)
        next.click() // → 4
        waitForLabel(step, toContain: "Step 4 of 7")
        next.click() // → 5
        waitForLabel(step, toContain: "Step 5 of 7")
        next.click() // → 6
        waitForLabel(step, toContain: "Step 6 of 7")
        next.click() // → 7
        waitForLabel(step, toContain: "Step 7 of 7")
        waitFor(element(AccessibilityID.Onboarding.finish)).click()
        waitUntilGone(window)

        openMenuBarPopover()
        waitForLabel(element(AccessibilityID.MenuBar.status), toContain: "Never cleaned")
        waitForLabel(element(AccessibilityID.MenuBar.levelRow("strong")), toContain: "10/10")
    }

    /// Regression: accepting the pre-selected level with Continue, without
    /// clicking a card, left zero targets enabled and the first blitz empty.
    func test_acceptingTheDefaultLevelEnablesItsTargets() throws {
        try sandbox.grantFullDiskAccess()
        for fixture in Fixture.basic { try sandbox.populate(fixture) }
        var options = LaunchOptions()
        options.onboardingComplete = false
        try launchApp(options)

        waitFor(window(titled: windowTitle))
        let step = element(AccessibilityID.Onboarding.stepIndicator)
        let next = element(AccessibilityID.Onboarding.next)
        for index in 1...6 {
            waitForLabel(step, toContain: "Step \(index) of 7")
            if index == 3 {
                waitForLabel(element(AccessibilityID.Onboarding.scanTitle), toContain: "Scan Complete")
            }
            waitUntilEnabled(next)
            next.click()
        }
        waitForLabel(step, toContain: "Step 7 of 7")
        waitForLabel(element(AccessibilityID.Onboarding.readySummary), toContain: "Will clean 18 targets · 12 KB estimated")
    }

    func test_quittingMidWayResumesOnTheSameStep() throws {
        try sandbox.grantFullDiskAccess()
        var options = LaunchOptions()
        options.onboardingComplete = false
        try launchApp(options)

        waitFor(window(titled: windowTitle))
        let step = element(AccessibilityID.Onboarding.stepIndicator)
        let next = element(AccessibilityID.Onboarding.next)
        next.click()
        waitForLabel(step, toContain: "Step 2 of 7")
        next.click()
        waitForLabel(step, toContain: "Step 3 of 7")
        waitForLabel(element(AccessibilityID.Onboarding.scanTitle), toContain: "Scan Complete")
        next.click()
        waitForLabel(step, toContain: "Step 4 of 7")

        try relaunchPreservingState()

        waitFor(window(titled: windowTitle))
        waitForLabel(element(AccessibilityID.Onboarding.stepIndicator), toContain: "Step 4 of 7")
    }

    func test_incompleteOnboardingIsOfferedFromTheMenuBar() throws {
        var options = LaunchOptions()
        options.onboardingComplete = false
        try launchApp(options)

        let window = waitFor(window(titled: windowTitle))
        closeWindow(window)

        openMenuBarPopover()
        XCTAssertFalse(element(AccessibilityID.MenuBar.blitzNow).exists, "no Blitz before setup")
        saveScreenshot("menubar-get-started", of: popoverWindow)
        waitFor(element(AccessibilityID.MenuBar.getStarted)).click()
        waitFor(self.window(titled: windowTitle))
    }
}
