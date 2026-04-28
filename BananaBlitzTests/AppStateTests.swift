import XCTest
@testable import BananaBlitz

final class AppStateTests: XCTestCase {

    private let testSuiteName = "com.bananablitz.tests"

    override func setUp() {
        super.setUp()
        // Use a clean UserDefaults domain so @AppStorage doesn't leak between tests.
        UserDefaults().removePersistentDomain(forName: testSuiteName)
    }

    func test_setDefaultTargets_basic() {
        let state = AppState()
        state.setDefaultTargets(for: .basic)
        XCTAssertEqual(state.enabledTargetIDs.count, PrivacyTarget.targets(for: .basic).count)
        XCTAssertTrue(state.enabledTargetIDs.contains("ad-privacy"))
        XCTAssertFalse(state.enabledTargetIDs.contains("biome"))
    }

    func test_setDefaultTargets_paranoidIncludesAll() {
        let state = AppState()
        state.setDefaultTargets(for: .paranoid)
        XCTAssertEqual(state.enabledTargetIDs.count, PrivacyTarget.allTargets.count)
    }

    func test_toggleTarget_flipsMembership() {
        let state = AppState()
        let target = PrivacyTarget.basicTargets[0]

        XCTAssertFalse(state.isTargetEnabled(target))
        state.toggleTarget(target)
        XCTAssertTrue(state.isTargetEnabled(target))
        state.toggleTarget(target)
        XCTAssertFalse(state.isTargetEnabled(target))
    }

    func test_addResult_capsHistoryAt200() {
        let state = AppState()
        for _ in 0..<250 {
            let result = CleaningResult(
                targetID: "ad-privacy",
                strategy: .wipeContents,
                bytesReclaimed: 1,
                success: true
            )
            state.addResult(result)
        }
        XCTAssertEqual(state.cleaningHistory.count, 200)
    }

    func test_addResult_failureDoesNotIncrementTotalsOrLastDate() {
        let state = AppState()
        state.addResult(CleaningResult(
            targetID: "ad-privacy",
            strategy: .wipeContents,
            bytesReclaimed: 999,
            success: false,
            error: "boom"
        ))
        XCTAssertEqual(state.totalBytesReclaimed, 0)
        XCTAssertNil(state.lastCleanDate)
    }

    func test_snapshotCleaningJobs_reflectsEnabledTargetsAndStrategies() {
        let state = AppState()
        state.setDefaultTargets(for: .basic)
        let target = PrivacyTarget.basicTargets[0]
        state.setStrategy(.replaceWithFile, for: target)

        let jobs = state.snapshotCleaningJobs()
        XCTAssertFalse(jobs.isEmpty)
        let job = jobs.first(where: { $0.target.id == target.id })
        XCTAssertNotNil(job)
        XCTAssertEqual(job?.strategy, .replaceWithFile)
    }

    func test_resetAll_clearsState() {
        let state = AppState()
        state.setDefaultTargets(for: .strong)
        state.totalBytesReclaimed = 12_345
        state.hasCompletedOnboarding = true

        state.resetAll()

        XCTAssertFalse(state.hasCompletedOnboarding)
        XCTAssertTrue(state.enabledTargetIDs.isEmpty)
        XCTAssertEqual(state.totalBytesReclaimed, 0)
        XCTAssertNil(state.lastCleanDate)
    }
}
