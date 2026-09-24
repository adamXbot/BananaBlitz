import XCTest
@testable import BananaBlitz

/// The dry run must describe what the cleaner will actually do — including
/// leaving locked targets alone — against a sandboxed temp directory.
final class DryRunTests: XCTestCase {

    private var sandbox: URL!
    private var guardService: FileSystemGuard!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        try super.setUpWithError()
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bananablitz-dryrun-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: sandbox, withIntermediateDirectories: true)
        guardService = FileSystemGuard(libraryRoot: sandbox.path)
    }

    override func tearDownWithError() throws {
        if let sandbox = sandbox, fm.fileExists(atPath: sandbox.path) {
            try fm.removeItem(at: sandbox)
        }
        sandbox = nil
        guardService = nil
        try super.tearDownWithError()
    }

    private func makeTarget(path: String) -> PrivacyTarget {
        PrivacyTarget(
            id: "test-\(UUID().uuidString.prefix(8))",
            name: "Test Target",
            description: "Test",
            path: path,
            level: .basic,
            sideEffect: "",
            supportedStrategies: [.wipeContents, .replaceWithFile, .deleteDatabases],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        )
    }

    private func plan(_ jobs: [CleaningJob]) -> [DryRunReport] {
        DryRun.plan(jobs: jobs, libraryRoot: sandbox.path, guardService: guardService)
    }

    func test_plan_reportsWhatAWipeWouldRemove() throws {
        let dir = sandbox.appendingPathComponent("cache")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try "ab".data(using: .utf8)!.write(to: dir.appendingPathComponent("a.bin"))
        try "cd".data(using: .utf8)!.write(to: dir.appendingPathComponent("b.bin"))

        let report = plan([CleaningJob(target: makeTarget(path: dir.path), strategy: .wipeContents)])[0]

        XCTAssertEqual(report.action, "Empty directory contents")
        XCTAssertEqual(report.itemsAtRisk, 2)
        XCTAssertEqual(report.bytesAtRisk, 4)
    }

    func test_plan_describesLockedTargetAsSkipped() throws {
        let dir = sandbox.appendingPathComponent("Biome")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = makeTarget(path: dir.path)
        try guardService.lockTarget(target)
        defer { try? guardService.unlockTarget(target) }

        let reports = plan([
            CleaningJob(target: target, strategy: .wipeContents),
            CleaningJob(target: target, strategy: .deleteDatabases),
            CleaningJob(target: target, strategy: .replaceWithFile),
        ])

        XCTAssertEqual(reports[0].action, DryRun.lockedSkipAction)
        XCTAssertEqual(reports[1].action, DryRun.lockedSkipAction)
        XCTAssertEqual(reports[2].action, DryRun.alreadyLockedAction)
        for report in reports {
            XCTAssertEqual(report.itemsAtRisk, 0)
            XCTAssertEqual(report.bytesAtRisk, 0)
        }
    }

    func test_plan_blocksPathsOutsideTheLibraryRoot() throws {
        let outside = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bananablitz-outside-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: outside) }

        let report = plan([CleaningJob(target: makeTarget(path: outside.path), strategy: .wipeContents)])[0]

        XCTAssertTrue(report.action.hasPrefix("Blocked:"), report.action)
        XCTAssertEqual(report.itemsAtRisk, 0)
    }
}
