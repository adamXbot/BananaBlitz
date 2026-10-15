import XCTest

/// Base class for the end-to-end suite. Each test launches the real app
/// against a fresh `SandboxHome`, so no test can read or modify the
/// developer's own `~/Library` or the real app's preferences.
class BananaBlitzUITestCase: XCTestCase {
    private(set) var app: XCUIApplication!
    private(set) var sandbox: SandboxHome!

    /// Default timeout for waits on UI that is expected to appear.
    let uiTimeout: TimeInterval = 10

    struct LaunchOptions {
        /// Seed `hasCompletedOnboarding = true` so the app starts in its
        /// steady state; `false` makes the onboarding window auto-open.
        var onboardingComplete = true
        /// Extra preference seeds (keys from `StorageKey`).
        var defaults: [String: Any] = [:]
        /// `"light"` or `"dark"`; nil keeps the system appearance.
        var appearance: String? = nil
        /// Keep preferences from the previous launch in this sandbox.
        var preserveState = false
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        sandbox = try SandboxHome()
        // Record any system alert that interrupts a test, then let XCTest's
        // default handling dismiss it; the screenshot says what it was.
        addUIInterruptionMonitor(withDescription: "System alert") { [weak self] alert in
            self?.saveScreenshot("interruption-\(Int(Date().timeIntervalSince1970))")
            NSLog("UI interruption: \(alert.debugDescription.prefix(400))")
            return false
        }
    }

    /// Screenshots are informational. If the display is re-enumerated while
    /// a test runs (a sleeping or re-attached monitor), XCTest records
    /// "Failed to look up screen N" from the capture; that must not fail an
    /// otherwise passing test.
    override func record(_ issue: XCTIssue) {
        if issue.compactDescription.contains("Failed to look up screen") { return }
        super.record(issue)
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
        try sandbox?.destroy()
        sandbox = nil
        try super.tearDownWithError()
    }

    // MARK: - Launching

    @discardableResult
    func launchApp(_ options: LaunchOptions = LaunchOptions()) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]

        var seed = options.defaults
        if options.onboardingComplete {
            seed[StorageKey.hasCompletedOnboarding] = true
        }
        let seedJSON = try JSONSerialization.data(withJSONObject: seed)

        var environment: [String: String] = [
            "CFFIXED_USER_HOME": sandbox.home.path,
            "BB_UITEST_HOME": sandbox.home.path,
            "BB_UITEST_DEFAULTS": String(decoding: seedJSON, as: UTF8.self),
        ]
        if let appearance = options.appearance {
            environment["BB_UITEST_APPEARANCE"] = appearance
        }
        if options.preserveState {
            environment["BB_UITEST_PRESERVE_STATE"] = "1"
        }
        app.launchEnvironment = environment
        app.launch()
        self.app = app
        return app
    }

    /// Quit and relaunch, keeping both the sandbox and the preference suite.
    func relaunchPreservingState() throws {
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: uiTimeout))
        var options = LaunchOptions()
        options.onboardingComplete = false // don't re-seed; the suite is preserved
        options.preserveState = true
        try launchApp(options)
    }

    // MARK: - Element lookup

    /// Any element carrying the accessibility identifier, regardless of role.
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func window(titled title: String) -> XCUIElement {
        app.windows[title]
    }

    /// The shared popover footer's Quit button: present in every popover
    /// state, so it marks the popover as open.
    var popoverAnchor: XCUIElement { app.buttons["Quit BananaBlitz"].firstMatch }

    /// The SwiftUI Settings scene (shared surface code). Its title is the
    /// selected tab's name, so it is recognised by its General tab instead.
    var settingsWindow: XCUIElement {
        app.windows.containing(NSPredicate(format: "label == 'General' OR title == 'General'")).firstMatch
    }

    /// The shared About window.
    var aboutWindow: XCUIElement { window(titled: "About BananaBlitz") }

    /// Close a window with its close button, falling back to ⌘W if the first
    /// click lands while the window is still animating in.
    func closeWindow(_ window: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        window.buttons[XCUIIdentifierCloseWindow].click()
        let gone = NSPredicate(format: "exists == false")
        if XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: gone, object: window)], timeout: 3) == .completed {
            return
        }
        window.click()
        app.typeKey("w", modifierFlags: .command)
        waitUntilGone(window, file: file, line: line)
    }

    @discardableResult
    func waitFor(_ element: XCUIElement, timeout: TimeInterval? = nil,
                 file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout ?? uiTimeout),
                      "Timed out waiting for \(element)", file: file, line: line)
        return element
    }

    func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval? = nil,
                       file: StaticString = #filePath, line: UInt = #line) {
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout ?? uiTimeout), .completed,
                       "\(element) is still present", file: file, line: line)
    }

    /// The text an element shows. On macOS a static text keeps its string in
    /// `value`, a button in `label`/`title`, a pop-up in `value`.
    func displayedText(of element: XCUIElement) -> String {
        [element.label, element.title, (element.value as? String) ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Wait until the element shows `text` (in its label, title or value).
    func waitForLabel(_ element: XCUIElement, toContain text: String, timeout: TimeInterval? = nil,
                      file: StaticString = #filePath, line: UInt = #line) {
        // Evaluating label/value on an element that is not there throws, so
        // poll existence first and only then read the text.
        let predicate = NSPredicate { object, _ in
            guard let element = object as? XCUIElement, element.exists else { return false }
            return self.displayedText(of: element).contains(text)
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout ?? uiTimeout), .completed,
                       "Expected \"\(text)\", got \"\(element.exists ? displayedText(of: element) : "<absent>")\"",
                       file: file, line: line)
    }

    /// Wait until the element exists and its text no longer contains `text`.
    func waitForLabel(_ element: XCUIElement, toNotContain text: String, timeout: TimeInterval? = nil,
                      file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate { object, _ in
            guard let element = object as? XCUIElement, element.exists else { return false }
            return !self.displayedText(of: element).contains(text)
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout ?? uiTimeout), .completed,
                       "Still showing \"\(text)\": \"\(element.exists ? displayedText(of: element) : "<absent>")\"",
                       file: file, line: line)
    }

    // MARK: - Menu bar

    /// Click the 🍌 status item and wait for the popover's contents.
    @discardableResult
    func openMenuBarPopover(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let anchor = popoverAnchor
        // The popover window stays in the hierarchy after it closes, so
        // "exists" is not enough; only a hittable popover is open.
        if anchor.exists && anchor.isHittable { return anchor }
        let item = app.statusItems.firstMatch
        waitFor(item, file: file, line: line)
        item.click()
        if waitUntilHittable(anchor, timeout: uiTimeout) { return anchor }
        if !anchor.exists {
            // The click was swallowed (the app was still activating); once more.
            item.click()
            if waitUntilHittable(anchor, timeout: uiTimeout) { return anchor }
        }
        saveScreenshot("popover-did-not-open")
        XCTFail(anchor.exists
                ? "The menu bar popover opened but is not hittable: something is covering the screen"
                : "The menu bar popover did not open",
                file: file, line: line)
        return anchor
    }

    @discardableResult
    func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @discardableResult
    func waitUntilNotHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false OR isHittable == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// The popover's own window (a borderless panel), for screenshots.
    var popoverWindow: XCUIElement {
        app.windows.containing(.button, identifier: "Quit BananaBlitz").firstMatch
    }

    /// The "Blitz Now" confirmation, which is its own window.
    var confirmWindow: XCUIElement { window(titled: "Confirm Blitz") }

    /// The front-most sheet, if any (dry run, self-test, confirmations).
    var frontSheet: XCUIElement { app.sheets.firstMatch }

    /// Opening the confirmation window closes the popover a moment later.
    /// Wait for that before opening it again, or the open is a no-op that
    /// races the close.
    @discardableResult
    func reopenPopoverAfterSheetDismissal() -> XCUIElement {
        _ = waitUntilNotHittable(popoverAnchor, timeout: 5)
        // When the confirmation window closes, the app drops back to accessory
        // mode a tick later, which would close a popover opened in that instant.
        let gone = NSPredicate(format: "exists == false")
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: gone, object: confirmWindow)], timeout: 5)
        Thread.sleep(forTimeInterval: 1)
        return openMenuBarPopover()
    }

    /// Close the popover if it is open by clicking the status item again.
    func closeMenuBarPopover() {
        let anchor = popoverAnchor
        guard anchor.exists && anchor.isHittable else { return }
        app.statusItems.firstMatch.click()
        _ = waitUntilNotHittable(anchor, timeout: uiTimeout)
    }

    /// Open a pop-up (SwiftUI `Picker` with `.menu` style) and choose an item.
    func choose(_ itemTitle: String, inPopUp identifier: String) {
        let popUp = waitFor(element(identifier))
        popUp.click()
        // Some items prefix the title with an emoji or icon, so fall back to
        // a containment match when no item has exactly this title.
        let exact = app.menuItems[itemTitle].firstMatch
        if exact.waitForExistence(timeout: 2) {
            exact.click()
            return
        }
        let predicate = NSPredicate(format: "title CONTAINS %@ OR label CONTAINS %@ OR value CONTAINS %@",
                                    itemTitle, itemTitle, itemTitle)
        let byAttribute = app.menuItems.matching(predicate).firstMatch
        if byAttribute.waitForExistence(timeout: 2) {
            byAttribute.click()
            return
        }
        // Items built from an HStack expose the text as a child element.
        let byChild = app.menuItems.containing(predicate).firstMatch
        waitFor(byChild)
        byChild.click()
    }

    /// Switch to a Settings toolbar tab by title ("General", "Targets",
    /// "Schedule", "Data", "Updates"). The tabs are shared surface code with
    /// no identifiers, so they are matched by label.
    func selectSettingsTab(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let byLabel = NSPredicate(format: "label == %@ OR title == %@", name, name)
        let inToolbar = settingsWindow.toolbars.descendants(matching: .any).matching(byLabel).firstMatch
        let tab = inToolbar.waitForExistence(timeout: 3)
            ? inToolbar
            : settingsWindow.descendants(matching: .any).matching(byLabel).firstMatch
        waitFor(tab, file: file, line: line).click()
    }

    /// Whether a segment reports itself selected (trait or value).
    func isSegmentSelected(_ segment: XCUIElement) -> Bool {
        segment.isSelected || isOn(segment)
    }

    /// A segment of a segmented picker, by its title.
    func segment(_ pickerIdentifier: String, _ title: String) -> XCUIElement {
        let picker = element(pickerIdentifier)
        let inPicker = picker.radioButtons[title].firstMatch
        return inPicker.exists ? inPicker : app.radioButtons[title].firstMatch
    }

    func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval? = nil,
                          file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout ?? uiTimeout), .completed,
                       "\(element) never became enabled", file: file, line: line)
    }

    /// Open Settings from the popover's gear and wait for the window.
    ///
    /// The popover stays open after the gear is clicked. On a small display
    /// (the 1024×768 CI runner) it then overlaps the Settings window and
    /// swallows clicks on the toolbar tabs, so it is closed explicitly once
    /// the window is up.
    @discardableResult
    func openSettings() -> XCUIElement {
        if settingsWindow.exists {
            closeMenuBarPopover()
            return settingsWindow
        }
        openMenuBarPopover()
        app.buttons["Settings"].firstMatch.click()
        let window = waitFor(settingsWindow)
        closeMenuBarPopover()
        return window
    }

    /// Open the About window from Settings ▸ General.
    @discardableResult
    func openAbout() -> XCUIElement {
        openSettings()
        selectSettingsTab("General")
        waitFor(settingsWindow.buttons["About BananaBlitz"].firstMatch).click()
        return waitFor(aboutWindow)
    }

    /// A button in the front-most alert or confirmation dialog. The generic
    /// `app.buttons[title]` can resolve to the Touch Bar mirror of the same
    /// button, which cannot be clicked.
    func dialogButton(_ title: String) -> XCUIElement {
        let inSheet = app.sheets.buttons[title].firstMatch
        if inSheet.exists { return inSheet }
        let inDialog = app.dialogs.buttons[title].firstMatch
        if inDialog.exists { return inDialog }
        // `hittable` is not a valid key path in an element query (Xcode 26
        // rejects it), so resolve the candidates and pick the hittable one.
        let byTitle = NSPredicate(format: "title == %@ OR label == %@", title, title)
        let candidates = app.buttons.matching(byTitle)
        if let hittable = candidates.allElementsBoundByIndex.first(where: { $0.isHittable }) {
            return hittable
        }
        return candidates.firstMatch
    }

    // MARK: - Checkboxes and switches

    func isOn(_ toggle: XCUIElement) -> Bool {
        if let value = toggle.value as? Int { return value != 0 }
        if let value = toggle.value as? String { return value == "1" || value.lowercased() == "on" }
        if let value = toggle.value as? Bool { return value }
        return false
    }

    // MARK: - Screenshots

    /// Attach a screenshot of `element` (or the whole screen) to the test
    /// result. The runner is sandboxed, so files cannot be written elsewhere;
    /// export them with `xcrun xcresulttool export attachments` (see
    /// `just test-ui`).
    func saveScreenshot(_ name: String, of element: XCUIElement? = nil) {
        // Fall back to the whole screen when the element is not on screen,
        // so a screenshot can never fail a test on its own.
        let screenshot = (element?.exists == true ? element?.screenshot() : nil) ?? XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
