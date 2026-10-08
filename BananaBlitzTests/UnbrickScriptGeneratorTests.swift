import XCTest
@testable import BananaBlitz

final class UnbrickScriptGeneratorTests: XCTestCase {

    func test_script_includesEveryTargetExactlyOnce() {
        let script = UnbrickScriptGenerator.script()
        for target in PrivacyTarget.allTargets {
            // ~/Library/... is rewritten to $HOME/Library/... in the script.
            let expected: String
            if target.path.hasPrefix("~/") {
                expected = "$HOME/" + String(target.path.dropFirst(2))
            } else {
                expected = target.path
            }
            let occurrences = script.components(separatedBy: "\"\(expected)\"").count - 1
            XCTAssertEqual(occurrences, 1, "expected one occurrence of \(expected) in script, found \(occurrences)")
        }
    }

    func test_script_separatesDirAndFileTargets() {
        let script = UnbrickScriptGenerator.script()
        XCTAssertTrue(script.contains("DIR_TARGETS=("))
        XCTAssertTrue(script.contains("FILE_TARGETS=("))
        // Specific-file target must land in FILE_TARGETS.
        guard let fileSection = script.range(of: "FILE_TARGETS=(") else {
            return XCTFail("FILE_TARGETS section missing")
        }
        let after = script[fileSection.upperBound...]
        XCTAssertTrue(after.contains("AutocorrectionRejections.db"),
                      "specific-file target should be in FILE_TARGETS section")
    }

    /// `Scripts/unbrick.sh` is committed and bundled into the app (and run
    /// by the Homebrew cask on uninstall), so it must match the generator.
    func test_bundledScript_matchesGenerator() throws {
        let scriptURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Scripts/unbrick.sh")
        let bundled = try String(contentsOf: scriptURL, encoding: .utf8)
        XCTAssertEqual(bundled, UnbrickScriptGenerator.script(),
                       "Scripts/unbrick.sh is stale; regenerate it with UnbrickScriptGenerator.write(to:)")
    }

    /// Homebrew runs the script on every uninstall, upgrade and reinstall, so
    /// the Dock and menu bar must only be restarted when a lock was removed.
    func test_script_killallSitsBehindChangedFlag() {
        let script = UnbrickScriptGenerator.script()
        let gated = """
            if [ "$CHANGED" -eq 1 ]; then
                echo "Restarting UI services to restore the menu bar..."
                killall ControlCenter SystemUIServer Dock 2>/dev/null || true
            else
                echo "No locked targets found."
            fi
            """
        XCTAssertTrue(script.contains(gated), "killall must run only when CHANGED=1")
        XCTAssertEqual(script.components(separatedBy: "killall").count - 1, 1,
                       "killall must not appear outside the CHANGED gate")
    }

    func test_script_setsChangedFlagInBothLoops() {
        let script = UnbrickScriptGenerator.script()
        guard let flagInit = script.range(of: "\nCHANGED=0\n"),
              let dirLoop = script.range(of: "for target in \"${DIR_TARGETS[@]}\"; do"),
              let fileLoop = script.range(of: "for target in \"${FILE_TARGETS[@]}\"; do"),
              let gate = script.range(of: "if [ \"$CHANGED\" -eq 1 ]; then") else {
            return XCTFail("script is missing the CHANGED flag, a target loop or the restart gate")
        }
        XCTAssertLessThan(flagInit.upperBound, dirLoop.lowerBound, "CHANGED must start at 0")
        XCTAssertTrue(script[dirLoop.upperBound..<fileLoop.lowerBound].contains("CHANGED=1"),
                      "directory loop must set CHANGED=1")
        XCTAssertTrue(script[fileLoop.upperBound..<gate.lowerBound].contains("CHANGED=1"),
                      "file loop must set CHANGED=1")
    }

    /// A file target is the user's real file rather than a stand-in, so the
    /// script must only remove it when it carries the user-immutable flag.
    func test_script_fileLoopOnlyActsOnImmutableFiles() {
        let script = UnbrickScriptGenerator.script()
        let guarded = """
            for target in "${FILE_TARGETS[@]}"; do
                if [ -e "$target" ] && is_user_immutable "$target"; then
            """
        XCTAssertTrue(script.contains(guarded), "file loop must check for uchg before removing anything")
        XCTAssertTrue(script.contains("*,uchg,*) return 0 ;;"), "is_user_immutable must match the uchg flag")
    }

    // MARK: - Running the script

    func test_runningScript_withNothingLocked_doesNotRestartUIServices() throws {
        let run = try runScript()

        XCTAssertEqual(run.status, 0, run.output)
        XCTAssertEqual(run.killallCalls, [], run.output)
        XCTAssertTrue(run.output.contains("No locked targets found."), run.output)
        XCTAssertFalse(run.output.contains("Restarting UI services"), run.output)
    }

    func test_runningScript_withLockedTarget_restartsUIServices() throws {
        let target = try XCTUnwrap(PrivacyTarget.allTargets.first { !$0.isSpecificFile })
        let relativePath = String(target.path.dropFirst(2))   // drop "~/"

        let run = try runScript { home in
            // A directory target collapsed to a locked file is what the app leaves behind.
            try Self.makeFile(at: home.appendingPathComponent(relativePath), immutable: true)
        }

        XCTAssertEqual(run.status, 0, run.output)
        XCTAssertEqual(run.killallCalls, ["ControlCenter SystemUIServer Dock"], run.output)
        XCTAssertTrue(run.output.contains("Restarting UI services"), run.output)
        XCTAssertFalse(run.output.contains("No locked targets found."), run.output)

        var isDir: ObjCBool = false
        let restored = run.home.appendingPathComponent(relativePath).path
        XCTAssertTrue(FileManager.default.fileExists(atPath: restored, isDirectory: &isDir) && isDir.boolValue,
                      "\(restored) should be a directory again")
    }

    func test_runningScript_leavesUnlockedFileTargetAlone() throws {
        let target = try XCTUnwrap(PrivacyTarget.allTargets.first { $0.isSpecificFile })
        let relativePath = String(target.path.dropFirst(2))   // drop "~/"

        let run = try runScript { home in
            try Self.makeFile(at: home.appendingPathComponent(relativePath), immutable: false)
        }

        XCTAssertEqual(run.status, 0, run.output)
        XCTAssertEqual(run.killallCalls, [], run.output)
        XCTAssertTrue(run.output.contains("No locked targets found."), run.output)
        XCTAssertTrue(FileManager.default.fileExists(atPath: run.home.appendingPathComponent(relativePath).path),
                      "an unlocked \(target.path) must not be deleted")
    }

    func test_runningScript_removesLockedFileTarget() throws {
        let target = try XCTUnwrap(PrivacyTarget.allTargets.first { $0.isSpecificFile })
        let relativePath = String(target.path.dropFirst(2))   // drop "~/"

        let run = try runScript { home in
            try Self.makeFile(at: home.appendingPathComponent(relativePath), immutable: true)
        }

        XCTAssertEqual(run.status, 0, run.output)
        XCTAssertEqual(run.killallCalls, ["ControlCenter SystemUIServer Dock"], run.output)
        XCTAssertTrue(run.output.contains("Unlocking and removing file"), run.output)
        XCTAssertFalse(FileManager.default.fileExists(atPath: run.home.appendingPathComponent(relativePath).path),
                       "a locked \(target.path) should be removed")
    }

    func test_write_producesExecutableFile() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("unbrick-\(UUID().uuidString).sh")
        defer { try? FileManager.default.removeItem(at: url) }

        try UnbrickScriptGenerator.write(to: url)

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
        XCTAssertEqual(perms & 0o777, 0o755)

        let body = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(body.hasPrefix("#!/bin/bash"))
        XCTAssertTrue(body.contains("Auto-generated"))
    }

    // MARK: - Helpers

    private struct ScriptRun {
        let status: Int32
        let output: String
        let killallCalls: [String]
        let home: URL
    }

    /// Run the generated script with `HOME` pointed at a scratch directory and
    /// `killall` stubbed on `PATH`, so nothing on this Mac is touched.
    private func runScript(prepareHome: (URL) throws -> Void = { _ in }) throws -> ScriptRun {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("unbrick-run-\(UUID().uuidString)")
        let home = root.appendingPathComponent("home")
        let bin = root.appendingPathComponent("bin")
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
        try fm.createDirectory(at: bin, withIntermediateDirectories: true)
        addTeardownBlock {
            // Clear any uchg flag the script didn't get to, or the tree can't be removed.
            let items = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
            while let item = items?.nextObject() as? URL {
                try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: item.path)
            }
            try? FileManager.default.removeItem(at: root)
        }

        let log = root.appendingPathComponent("killall.log")
        let stub = bin.appendingPathComponent("killall")
        try "#!/bin/sh\necho \"$*\" >> \"$KILLALL_LOG\"\n".write(to: stub, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stub.path)

        try prepareHome(home)

        let script = root.appendingPathComponent("unbrick.sh")
        try UnbrickScriptGenerator.write(to: script)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        process.environment = [
            "HOME": home.path,
            "PATH": "\(bin.path):/usr/bin:/bin:/usr/sbin:/sbin",
            "KILLALL_LOG": log.path,
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let calls = (try? String(contentsOf: log, encoding: .utf8))?
            .split(separator: "\n").map(String.init) ?? []
        return ScriptRun(status: process.terminationStatus,
                         output: String(decoding: output, as: UTF8.self),
                         killallCalls: calls,
                         home: home)
    }

    /// Create an empty file at `url`, optionally with the user-immutable (`uchg`) flag.
    private static func makeFile(at url: URL, immutable: Bool) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: url)
        if immutable {
            try fm.setAttributes([.immutable: true], ofItemAtPath: url.path)
        }
    }
}
