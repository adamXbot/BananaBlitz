import XCTest

/// Captures every surface in light and dark appearance. Assertions are
/// minimal; the value is the screenshot set attached to the result bundle
/// (export it with `just ui-test`) for a visual check before a release.
final class VisualReviewUITests: BananaBlitzUITestCase {

    func test_lightAppearance() throws {
        try captureEverySurface(appearance: "light")
    }

    func test_darkAppearance() throws {
        try captureEverySurface(appearance: "dark")
    }

    private func captureEverySurface(appearance: String) throws {
        try sandbox.grantFullDiskAccess()
        for fixture in Fixture.basic + [.suggestions, .knowledgeC] { try sandbox.populate(fixture) }
        try sandbox.populate(.keyboardProfiling)

        var options = LaunchOptions()
        options.onboardingComplete = false
        options.appearance = appearance
        try launchApp(options)

        // Setup wizard, every step.
        let onboarding = waitFor(window(titled: "Welcome to BananaBlitz"))
        let step = element(AccessibilityID.Onboarding.stepIndicator)
        let next = element(AccessibilityID.Onboarding.next)
        let names = ["welcome", "permission", "scan", "snapshot", "level", "schedule", "clean"]
        for (index, name) in names.enumerated() {
            waitForLabel(step, toContain: "Step \(index + 1) of 7")
            if name == "scan" {
                waitForLabel(element(AccessibilityID.Onboarding.scanTitle), toContain: "Scan Complete")
            }
            if name == "clean" {
                waitFor(element(AccessibilityID.Onboarding.readyTitle))
            }
            saveScreenshot("\(appearance)-onboarding-\(index + 1)-\(name)", of: onboarding)
            if index < names.count - 1 {
                waitUntilEnabled(next)
                next.click()
            }
        }
        element(AccessibilityID.Onboarding.blitz).click()
        waitForLabel(element(AccessibilityID.DryRun.title), toContain: "Confirm First Blitz")
        saveScreenshot("\(appearance)-onboarding-confirm", of: onboarding)
        element(AccessibilityID.DryRun.confirm).click()
        waitForLabel(element(AccessibilityID.Onboarding.completionTitle), toContain: "All Clean", timeout: 30)
        saveScreenshot("\(appearance)-onboarding-complete", of: onboarding)
        let finish = element(AccessibilityID.Onboarding.finish)
        waitUntilEnabled(finish)
        finish.click()
        waitUntilGone(onboarding)
        // The app drops back to accessory mode a tick after its last window
        // closes, which would close a popover opened in that instant.
        Thread.sleep(forTimeInterval: 1)

        // Menu bar.
        openMenuBarPopover()
        saveScreenshot("\(appearance)-menubar-popover", of: popoverWindow)
        element(AccessibilityID.MenuBar.blitzNow).click()
        waitFor(confirmWindow)
        waitForLabel(element(AccessibilityID.DryRun.title), toContain: "Confirm Blitz")
        saveScreenshot("\(appearance)-menubar-confirm", of: confirmWindow)
        element(AccessibilityID.DryRun.cancel).click()
        waitUntilGone(confirmWindow)
        Thread.sleep(forTimeInterval: 1)

        // Settings panes and sheets.
        let settings = openSettings()
        selectSettingsTab("General")
        waitFor(element(AccessibilityID.Settings.fullDiskAccessStatus))
        saveScreenshot("\(appearance)-settings-general", of: settings)

        selectSettingsTab("Targets")
        waitFor(element(AccessibilityID.Targets.row(Fixture.adPrivacy.id))).click()
        waitFor(element(AccessibilityID.Targets.strategy(Fixture.adPrivacy.id)))
        saveScreenshot("\(appearance)-settings-targets", of: settings)
        collapseTargetRow(Fixture.adPrivacy.id)

        selectSettingsTab("Schedule")
        waitFor(element(AccessibilityID.Settings.scheduleInterval))
        saveScreenshot("\(appearance)-settings-schedule", of: settings)

        selectSettingsTab("Data")
        waitFor(element(AccessibilityID.Settings.dryRun))
        saveScreenshot("\(appearance)-settings-data", of: settings)

        element(AccessibilityID.Settings.dryRun).click()
        waitForLabel(element(AccessibilityID.DryRun.title), toContain: "Preview Next Clean")
        saveScreenshot("\(appearance)-settings-dry-run", of: settings)
        element(AccessibilityID.DryRun.close).click()
        waitUntilGone(element(AccessibilityID.DryRun.title))

        element(AccessibilityID.Settings.selfTest).click()
        waitFor(element(AccessibilityID.SelfTest.title))
        saveScreenshot("\(appearance)-settings-self-test", of: settings)
        element(AccessibilityID.SelfTest.close).click()
        waitUntilGone(element(AccessibilityID.SelfTest.title))

        settings.buttons["Reset All Settings…"].firstMatch.click()
        waitFor(dialogButton("Reset Everything"))
        saveScreenshot("\(appearance)-settings-reset-confirm", of: frontSheet)
        dialogButton("Cancel").click()

        selectSettingsTab("Updates")
        Thread.sleep(forTimeInterval: 1)
        saveScreenshot("\(appearance)-settings-updates", of: settings)

        // About.
        let about = openAbout()
        saveScreenshot("\(appearance)-about", of: about)
    }
}
