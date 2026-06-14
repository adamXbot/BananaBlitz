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

    // MARK: - Crash-safe lock (partial-failure restore)

    /// Simulate a `chflags` denial: the immutable-flag set fails *after* the
    /// directory has been moved aside. The original must be restored intact —
    /// never left destroyed (the bug the old "delete first" ordering had).
    func test_lockTarget_restoresOriginalWhenImmutableFlagFails() throws {
        let failingGuard = FileSystemGuard(libraryRoot: sandbox.path) { _, immutable in
            if immutable { throw BananaBlitzError.immutableFlagFailed("test", "simulated") }
        }
        let dir = sandbox.appendingPathComponent("biome")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let sentinel = dir.appendingPathComponent("important.data")
        try "user-data".data(using: .utf8)!.write(to: sentinel)
        let target = makeTarget(path: dir.path)

        XCTAssertThrowsError(try failingGuard.lockTarget(target)) { error in
            guard case BananaBlitzError.immutableFlagFailed = error else {
                return XCTFail("expected immutableFlagFailed, got \(error)")
            }
        }

        // Original directory and its contents are restored.
        var isDir: ObjCBool = false
        XCTAssertTrue(fm.fileExists(atPath: dir.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue, "expected the original directory to be restored")
        XCTAssertEqual(try String(contentsOf: sentinel, encoding: .utf8), "user-data")
        XCTAssertFalse(failingGuard.isLocked(target))

        // The backup was moved back, not orphaned.
        let leftovers = try fm.contentsOfDirectory(atPath: sandbox.path)
            .filter { $0.contains(".bananablitz-bak-") }
        XCTAssertEqual(leftovers, [], "backup must be restored, not left behind")
    }

    func test_lockTarget_removesBackupOnSuccess() throws {
        let testGuard = FileSystemGuard(libraryRoot: sandbox.path)
        let dir = sandbox.appendingPathComponent("biome")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try "x".data(using: .utf8)!.write(to: dir.appendingPathComponent("f"))
        let target = makeTarget(path: dir.path)

        try testGuard.lockTarget(target)

        XCTAssertTrue(testGuard.isLocked(target))
        let leftovers = try fm.contentsOfDirectory(atPath: sandbox.path)
            .filter { $0.contains(".bananablitz-bak-") }
        XCTAssertEqual(leftovers, [], "successful lock must not leave a backup behind")
    }

    func test_lockTarget_reLockOfAlreadyLockedTargetSucceeds() throws {
        let testGuard = FileSystemGuard(libraryRoot: sandbox.path)
        let dir = sandbox.appendingPathComponent("biome")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = makeTarget(path: dir.path)

        try testGuard.lockTarget(target)
        XCTAssertTrue(testGuard.isLocked(target))
        // Re-locking clears the old flag, replaces, and re-locks cleanly.
        try testGuard.lockTarget(target)
        XCTAssertTrue(testGuard.isLocked(target))

        let leftovers = try fm.contentsOfDirectory(atPath: sandbox.path)
            .filter { $0.contains(".bananablitz-bak-") }
        XCTAssertEqual(leftovers, [])

        try testGuard.unlockTarget(target)
        XCTAssertFalse(testGuard.isLocked(target))
    }

    /// The other catch-triggering branch: createFile itself fails (returns
    /// false) *after* the original was moved aside. The original must still be
    /// restored intact.
    func test_lockTarget_restoresOriginalWhenCreateFileFails() throws {
        let failingGuard = FileSystemGuard(libraryRoot: sandbox.path, lockFileCreator: { _ in
            throw BananaBlitzError.failedToCreateLockFile("test")
        })
        let dir = sandbox.appendingPathComponent("biome")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let sentinel = dir.appendingPathComponent("important.data")
        try "user-data".data(using: .utf8)!.write(to: sentinel)
        let target = makeTarget(path: dir.path)

        XCTAssertThrowsError(try failingGuard.lockTarget(target)) { error in
            guard case BananaBlitzError.failedToCreateLockFile = error else {
                return XCTFail("expected failedToCreateLockFile, got \(error)")
            }
        }

        var isDir: ObjCBool = false
        XCTAssertTrue(fm.fileExists(atPath: dir.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue, "expected the original directory to be restored")
        XCTAssertEqual(try String(contentsOf: sentinel, encoding: .utf8), "user-data")
        let leftovers = try fm.contentsOfDirectory(atPath: sandbox.path)
            .filter { $0.contains(".bananablitz-bak-") }
        XCTAssertEqual(leftovers, [], "backup must be restored, not left behind")
    }

    /// The no-prior-data branch: locking a path that doesn't exist yet should
    /// create the lock file directly and never make a backup.
    func test_lockTarget_locksNonExistentPathDirectly() throws {
        let testGuard = FileSystemGuard(libraryRoot: sandbox.path)
        let path = sandbox.appendingPathComponent("never-existed").path
        let target = makeTarget(path: path)
        XCTAssertFalse(fm.fileExists(atPath: path))

        try testGuard.lockTarget(target)

        var isDir: ObjCBool = false
        XCTAssertTrue(fm.fileExists(atPath: path, isDirectory: &isDir))
        XCTAssertFalse(isDir.boolValue, "expected a lock file, not a directory")
        XCTAssertTrue(testGuard.isLocked(target))
        let leftovers = try fm.contentsOfDirectory(atPath: sandbox.path)
            .filter { $0.contains(".bananablitz-bak-") }
        XCTAssertEqual(leftovers, [], "no backup for a path that never existed")
    }
}
