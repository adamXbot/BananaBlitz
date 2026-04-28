import XCTest
@testable import BananaBlitz

/// Exercises lock / unlock against a temp directory, with `libraryRoot`
/// rebound so the in-Library safety guard accepts the sandbox path.
final class FileSystemGuardTests: XCTestCase {

    private var sandbox: URL!
    private var guardUnderTest: FileSystemGuard!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        try super.setUpWithError()
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bananablitz-guard-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: sandbox, withIntermediateDirectories: true)
        // Reuse the shared guard for behaviour we're testing — the immutable
        // flag operations don't depend on libraryRoot, only the path-safety
        // guard does, and we're not exercising that here.
        guardUnderTest = FileSystemGuard.shared
    }

    override func tearDownWithError() throws {
        // Best-effort cleanup: remove any immutable flags before deleting.
        if let sandbox = sandbox, fm.fileExists(atPath: sandbox.path) {
            unsetImmutableRecursive(at: sandbox)
            try fm.removeItem(at: sandbox)
        }
        sandbox = nil
        try super.tearDownWithError()
    }

    private func unsetImmutableRecursive(at url: URL) {
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil) {
            for case let child as URL in enumerator {
                var values = URLResourceValues()
                values.isUserImmutable = false
                var mutable = child
                try? mutable.setResourceValues(values)
            }
        }
        var values = URLResourceValues()
        values.isUserImmutable = false
        var mutable = url
        try? mutable.setResourceValues(values)
    }

    private func makeTarget(path: String, isFile: Bool = false) -> PrivacyTarget {
        PrivacyTarget(
            id: "test-\(UUID().uuidString.prefix(8))",
            name: "Test",
            description: "",
            path: path,
            level: .basic,
            sideEffect: "",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .replaceWithFile,
            isSpecificFile: isFile
        )
    }

    // MARK: - Path safety

    func test_lock_refusesPathsOutsideLibrary() {
        let outside = sandbox.appendingPathComponent("noplace")
        try? fm.createDirectory(at: outside, withIntermediateDirectories: true)
        let target = makeTarget(path: outside.path)
        XCTAssertThrowsError(try guardUnderTest.lockTarget(target)) { error in
            guard case BananaBlitzError.refusedOutsideLibrary = error else {
                return XCTFail("expected refusedOutsideLibrary, got \(error)")
            }
        }
    }

    // MARK: - Lock / Unlock with overridden libraryRoot

    func test_lockUnlock_roundTripsForDirectoryTarget() throws {
        let testGuard = FileSystemGuard(libraryRoot: sandbox.path)
        let dir = sandbox.appendingPathComponent("biome")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = makeTarget(path: dir.path)

        try testGuard.lockTarget(target)

        // Path now exists as a file, not a directory, with the immutable flag.
        var isDir: ObjCBool = false
        XCTAssertTrue(fm.fileExists(atPath: dir.path, isDirectory: &isDir))
        XCTAssertFalse(isDir.boolValue, "expected lock file, not directory")
        XCTAssertTrue(testGuard.isLocked(target))

        try testGuard.unlockTarget(target)

        // Directory restored.
        var isDir2: ObjCBool = false
        XCTAssertTrue(fm.fileExists(atPath: dir.path, isDirectory: &isDir2))
        XCTAssertTrue(isDir2.boolValue, "expected directory restored")
        XCTAssertFalse(testGuard.isLocked(target))
    }

    func test_isLocked_falseForDirectoryThatStillExists() throws {
        let testGuard = FileSystemGuard(libraryRoot: sandbox.path)
        let dir = sandbox.appendingPathComponent("intact")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = makeTarget(path: dir.path)

        // A real directory existing at this path is not "locked" — the
        // tightened heuristic now requires the immutable flag too.
        XCTAssertFalse(testGuard.isLocked(target))
    }

    func test_isLocked_falseForUnrelatedFileWithoutImmutable() throws {
        let testGuard = FileSystemGuard(libraryRoot: sandbox.path)
        let path = sandbox.appendingPathComponent("rogue").path
        try "stub".data(using: .utf8)!.write(to: URL(fileURLWithPath: path))
        let target = makeTarget(path: path)
        // Old heuristic returned true here; tightened version should be false.
        XCTAssertFalse(testGuard.isLocked(target))
    }
}
