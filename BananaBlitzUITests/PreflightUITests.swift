import XCTest

/// Runs first and alone in CI (see ci.yml). The UI suite drives the real
/// screen, so a system dialog left open on the runner (a permission prompt,
/// a Dictation notice, a crashed-app alert) steals every click and makes
/// unrelated tests fail with "not hittable". This turns that into one
/// clear, early failure.
final class PreflightUITests: BananaBlitzUITestCase {

    func test_screenAcceptsClicks() throws {
        try launchApp()
        let item = app.statusItems.firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: uiTimeout),
                      "The app's menu bar item never appeared. Is a GUI session available?")
        item.click()
        let anchor = popoverAnchor
        guard waitUntilHittable(anchor, timeout: uiTimeout) else {
            saveScreenshot("preflight-obstructed")
            XCTFail("""
                The popover opened but is not hittable: something is covering the screen \
                (a system dialog, a permission prompt, or another app's modal window). \
                Dismiss it on the runner before running the UI suite. See the attached screenshot.
                """)
            return
        }
        closeMenuBarPopover()
    }
}
