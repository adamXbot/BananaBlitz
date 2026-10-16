import XCTest

/// The two Settings ▸ Data actions that go through a real save panel. The
/// panel is driven with ⌘⇧G (Go to Folder) so the file lands inside the
/// sandbox home, never in the developer's own folders.
final class DataExportUITests: BananaBlitzUITestCase {

    /// Type a destination into the open save panel and confirm it.
    private func saveInPanel(directory: URL, filename: String) {
        let panel = app.sheets.firstMatch.exists ? app.sheets.firstMatch : app.dialogs.firstMatch
        waitFor(panel)
        // Go to Folder: replace whatever path the field already holds (the
        // panel remembers the last folder), confirm, then set the name.
        app.typeKey("g", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.7)
        app.typeKey("a", modifierFlags: .command)
        app.typeText(directory.path)
        app.typeKey(.return, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.7)
        // The name field, not the Go to Folder or search field.
        let candidates = [panel.textFields["saveAsNameTextField"], panel.textFields["Save As:"], panel.textFields.firstMatch]
        let nameField = candidates.first { $0.exists } ?? panel.textFields.firstMatch
        waitFor(nameField)
        for _ in 0..<2 where (nameField.value as? String) != filename {
            nameField.click()
            app.typeKey("a", modifierFlags: .command)
            app.typeText(filename)
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertEqual(nameField.value as? String, filename, "could not set the save panel's file name")
        let save = panel.buttons["Save"].firstMatch
        if save.exists { save.click() } else { app.typeKey(.return, modifierFlags: []) }
        waitUntilGone(panel)
        // Replace-existing-file confirmation, if the name was reused.
        let replace = app.sheets.buttons["Replace"].firstMatch
        if replace.waitForExistence(timeout: 1) { replace.click() }
    }

    func test_saveRecoveryScriptWritesAnExecutableScript() throws {
        try launchApp()
        openSettings()
        selectSettingsTab("Data")
        clickControl(element(AccessibilityID.Settings.saveRecoveryScript))

        let destination = sandbox.home.appendingPathComponent("unbrick.sh")
        saveInPanel(directory: sandbox.home, filename: "unbrick.sh")

        waitForLabel(element(AccessibilityID.Settings.recoveryStatus), toContain: "Saved to")
        let contents = try String(contentsOf: destination, encoding: .utf8)
        XCTAssertTrue(contents.hasPrefix("#!/bin/bash"), "script should start with a shebang")
        XCTAssertTrue(contents.contains("chflags nouchg"), "script should clear immutable flags")
        XCTAssertTrue(contents.contains("com.apple.ap.adprivacyd"), "script should list the registry paths")
        let permissions = try FileManager.default.attributesOfItem(atPath: destination.path)[.posixPermissions] as? Int
        XCTAssertEqual((permissions ?? 0) & 0o111, 0o111, "script should be executable")
    }

    func test_exportHistoryWritesJSONAndCSV() throws {
        try sandbox.grantFullDiskAccess()
        try sandbox.populate(.adPrivacy)
        try launchApp()

        // Make some history first.
        openMenuBarPopover()
        element(AccessibilityID.MenuBar.blitzNow).click()
        waitFor(element(AccessibilityID.DryRun.confirm)).click()
        reopenPopoverAfterSheetDismissal()
        waitForLabel(element(AccessibilityID.MenuBar.outcome), toContain: "Cleaned", timeout: 30)

        openSettings()
        selectSettingsTab("Data")

        clickControl(element(AccessibilityID.Settings.exportHistory))
        saveInPanel(directory: sandbox.home, filename: "history.json")
        waitForLabel(element(AccessibilityID.Settings.historyStatus), toContain: "History saved to")
        let json = try Data(contentsOf: sandbox.home.appendingPathComponent("history.json"))
        let entries = try XCTUnwrap(try JSONSerialization.jsonObject(with: json) as? [[String: Any]])
        XCTAssertEqual(entries.count, 18, "one entry per enabled target")
        XCTAssertTrue(entries.contains { ($0["targetID"] as? String) == Fixture.adPrivacy.id })

        clickControl(element(AccessibilityID.Settings.exportHistory))
        saveInPanel(directory: sandbox.home, filename: "history.csv")
        let csvURL = sandbox.home.appendingPathComponent("history.csv")
        let written = NSPredicate { _, _ in FileManager.default.fileExists(atPath: csvURL.path) }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: written, object: nil)], timeout: uiTimeout),
                       .completed, "history.csv was not written")
        waitForLabel(element(AccessibilityID.Settings.historyStatus), toContain: "history.csv")
        let csv = try String(contentsOf: csvURL, encoding: .utf8)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.first, "timestamp,target_id,target_name,strategy,success,bytes_reclaimed,error,note")
        XCTAssertEqual(lines.count, 19, "header plus one row per entry")
    }
}
