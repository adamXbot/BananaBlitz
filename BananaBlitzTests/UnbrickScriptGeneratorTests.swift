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
}
