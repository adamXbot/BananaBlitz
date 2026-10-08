import XCTest
@testable import BananaBlitz

/// Guards the cask template, `packaging/homebrew/bananablitz.rb`.
/// Homebrew runs the bundled `unbrick.sh` in a sandbox that only allows
/// writes to the cask's `writable_paths`, so a target missing from that
/// list silently stays locked after `brew uninstall`.
final class HomebrewCaskTests: XCTestCase {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // BananaBlitzTests/
        .deletingLastPathComponent()   // repo root

    func test_caskWritablePaths_coverEveryTarget() throws {
        let caskURL = Self.repoRoot.appendingPathComponent("packaging/homebrew/bananablitz.rb")
        let cask = try String(contentsOf: caskURL, encoding: .utf8)

        guard let open = cask.range(of: "writable_paths: ["),
              let close = cask.range(of: "]", range: open.upperBound..<cask.endIndex) else {
            return XCTFail("writable_paths array missing from packaging/homebrew/bananablitz.rb")
        }
        // Every odd-indexed piece of a `"`-split is a quoted string.
        let listed = cask[open.upperBound..<close.lowerBound]
            .components(separatedBy: "\"")
            .enumerated()
            .filter { $0.offset % 2 == 1 }
            .map(\.element)

        // The cask declares these relative to `writable_base: :home`.
        let expected = PrivacyTarget.allTargets.map { target -> String in
            XCTAssertTrue(target.path.hasPrefix("~/"), "\(target.path) is not under ~/")
            return String(target.path.dropFirst(2))
        }

        XCTAssertEqual(listed.count, Set(listed).count, "writable_paths has duplicates")
        XCTAssertEqual(Set(listed).subtracting(expected), [], "writable_paths lists non-targets")
        XCTAssertEqual(Set(expected).subtracting(listed), [], "writable_paths is missing targets")
    }
}
