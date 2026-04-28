import XCTest
@testable import BananaBlitz

/// Tests cover the three cleaning strategies against a sandboxed temp directory.
/// We never touch real `~/Library` paths in tests.
final class PrivacyCleanerTests: XCTestCase {

    private var sandbox: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        try super.setUpWithError()
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bananablitz-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: sandbox, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let sandbox = sandbox, fm.fileExists(atPath: sandbox.path) {
            try fm.removeItem(at: sandbox)
        }
        sandbox = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeTarget(
        path: String,
        strategies: [CleaningStrategy] = [.wipeContents, .replaceWithFile, .deleteDatabases],
        defaultStrategy: CleaningStrategy = .wipeContents,
        isFile: Bool = false
    ) -> PrivacyTarget {
        PrivacyTarget(
            id: "test-\(UUID().uuidString.prefix(8))",
            name: "Test Target",
            description: "Test",
            path: path,
            level: .basic,
            sideEffect: "",
            supportedStrategies: strategies,
            defaultStrategy: defaultStrategy,
            isSpecificFile: isFile
        )
    }

    private func writeFile(_ name: String, in dir: URL, contents: String = "x") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try contents.data(using: .utf8)!.write(to: url)
        return url
    }

    // MARK: - wipeContents

    func test_wipeContents_emptiesDirectoryButKeepsItPresent() throws {
        let dir = sandbox.appendingPathComponent("cache")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        _ = try writeFile("a.bin", in: dir)
        _ = try writeFile("b.bin", in: dir)

        let target = makeTarget(path: dir.path)
        let result = PrivacyCleaner.shared.clean(target: target, strategy: .wipeContents)

        XCTAssertTrue(result.success, "expected success, got \(String(describing: result.error))")
        XCTAssertTrue(fm.fileExists(atPath: dir.path), "directory itself should be retained")
        let contents = try fm.contentsOfDirectory(atPath: dir.path)
        XCTAssertEqual(contents, [], "directory should be empty")
    }

    func test_wipeContents_isNoOpForMissingPath() {
        let missing = sandbox.appendingPathComponent("does-not-exist")
        let target = makeTarget(path: missing.path)
        let result = PrivacyCleaner.shared.clean(target: target, strategy: .wipeContents)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.bytesReclaimed, 0)
    }

    // MARK: - deleteDatabases

    func test_deleteDatabases_removesOnlyDatabaseExtensions() throws {
        let dir = sandbox.appendingPathComponent("dbs")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        _ = try writeFile("keep.txt", in: dir)
        _ = try writeFile("foo.db", in: dir)
        _ = try writeFile("bar.sqlite", in: dir)
        _ = try writeFile("baz.segb", in: dir)
        _ = try writeFile("qux.sqlite-wal", in: dir)

        let target = makeTarget(path: dir.path)
        let result = PrivacyCleaner.shared.clean(target: target, strategy: .deleteDatabases)
        XCTAssertTrue(result.success)

        let remaining = Set(try fm.contentsOfDirectory(atPath: dir.path))
        XCTAssertEqual(remaining, ["keep.txt"])
    }

    func test_deleteDatabases_recursesIntoSubdirectories() throws {
        let dir = sandbox.appendingPathComponent("nested")
        let sub = dir.appendingPathComponent("sub")
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        _ = try writeFile("a.db", in: sub)
        _ = try writeFile("b.txt", in: sub)

        let target = makeTarget(path: dir.path)
        let result = PrivacyCleaner.shared.clean(target: target, strategy: .deleteDatabases)
        XCTAssertTrue(result.success)

        XCTAssertFalse(fm.fileExists(atPath: sub.appendingPathComponent("a.db").path))
        XCTAssertTrue(fm.fileExists(atPath: sub.appendingPathComponent("b.txt").path))
    }

    // MARK: - Specific-file targets

    func test_wipeContents_onSpecificFileRemovesIt() throws {
        let file = try writeFile("kbd.db", in: sandbox)
        let target = makeTarget(path: file.path, isFile: true)
        let result = PrivacyCleaner.shared.clean(target: target, strategy: .wipeContents)
        XCTAssertTrue(result.success)
        XCTAssertFalse(fm.fileExists(atPath: file.path))
    }
}
