import XCTest
@testable import BananaBlitz

/// Covers the unattended-run strategy sanitiser. Scheduled cleans have no
/// confirmation gate, so the destructive "Lock with Immutable File" strategy
/// must be downgraded to a plain wipe unless the user has explicitly opted in.
final class SchedulerServiceTests: XCTestCase {

    private var tempURL: URL!

    private static let userDefaultsKeysToClear: [String] = [
        StorageKey.selectedLevelRaw,
        StorageKey.scheduleIntervalRaw,
        StorageKey.notificationStyleRaw,
        StorageKey.isPaused,
        StorageKey.globalStrategyRaw,
        StorageKey.allowAggressiveScheduledClean,
    ]

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bananablitz-sched-\(UUID().uuidString).json")
        clearUserDefaults()
    }

    override func tearDownWithError() throws {
        if let url = tempURL, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        tempURL = nil
        clearUserDefaults()
        try super.tearDownWithError()
    }

    private func clearUserDefaults() {
        for key in Self.userDefaultsKeysToClear {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func makeTarget(_ id: String, strategies: [CleaningStrategy]) -> PrivacyTarget {
        PrivacyTarget(
            id: id,
            name: id,
            description: "",
            path: "~/Library/\(id)",
            level: .basic,
            sideEffect: "",
            supportedStrategies: strategies,
            defaultStrategy: strategies.first ?? .wipeContents,
            isSpecificFile: false
        )
    }

    func test_sanitiseForUnattendedRun_downgradesAggressiveWhenNotAllowed() {
        let jobs = [
            CleaningJob(target: makeTarget("a", strategies: [.wipeContents, .replaceWithFile]),
                        strategy: .replaceWithFile),
            CleaningJob(target: makeTarget("b", strategies: [.wipeContents]),
                        strategy: .wipeContents),
            CleaningJob(target: makeTarget("c", strategies: [.deleteDatabases]),
                        strategy: .deleteDatabases),
        ]

        let safe = SchedulerService.sanitiseForUnattendedRun(jobs, allowAggressive: false)

        XCTAssertEqual(safe.count, 3)
        XCTAssertEqual(safe[0].strategy, .wipeContents, "aggressive lock must be downgraded")
        XCTAssertEqual(safe[1].strategy, .wipeContents)
        XCTAssertEqual(safe[2].strategy, .deleteDatabases, "non-aggressive strategies unchanged")
        XCTAssertEqual(safe.map(\.target.id), ["a", "b", "c"], "targets preserved 1:1 and in order")
    }

    func test_sanitiseForUnattendedRun_passesThroughWhenAllowed() {
        let jobs = [
            CleaningJob(target: makeTarget("a", strategies: [.wipeContents, .replaceWithFile]),
                        strategy: .replaceWithFile),
        ]
        let kept = SchedulerService.sanitiseForUnattendedRun(jobs, allowAggressive: true)
        XCTAssertEqual(kept[0].strategy, .replaceWithFile, "opt-in keeps the aggressive strategy")
    }

    /// The downgrade is only valid if every `replaceWithFile`-capable target
    /// also supports `wipeContents`. Enforce that invariant across the registry
    /// so a future target can't silently make the downgrade pick an
    /// unsupported strategy.
    func test_everyAggressiveTargetAlsoSupportsWipe() {
        for target in PrivacyTarget.allTargets where target.supportedStrategies.contains(.replaceWithFile) {
            XCTAssertTrue(
                target.supportedStrategies.contains(.wipeContents),
                "\(target.id) supports replaceWithFile but not wipeContents — unattended downgrade would be invalid"
            )
        }
    }

    // MARK: - Wiring (snapshot -> sanitise -> flag) used by performScheduledClean

    func test_unattendedJobs_downgradesAggressiveWhenFlagOff() {
        let state = AppState(persistenceURL: tempURL)
        state.setDefaultTargets(for: .basic)
        let t = PrivacyTarget.basicTargets[0]
        state.setStrategy(.replaceWithFile, for: t)
        state.allowAggressiveScheduledClean = false

        let jobs = SchedulerService.unattendedJobs(for: state)
        let job = jobs.first { $0.target.id == t.id }
        XCTAssertEqual(job?.strategy, .wipeContents, "scheduled run must downgrade the lock by default")
    }

    func test_unattendedJobs_keepsAggressiveWhenFlagOn() {
        let state = AppState(persistenceURL: tempURL)
        state.setDefaultTargets(for: .basic)
        let t = PrivacyTarget.basicTargets[0]
        state.setStrategy(.replaceWithFile, for: t)
        state.allowAggressiveScheduledClean = true

        let jobs = SchedulerService.unattendedJobs(for: state)
        let job = jobs.first { $0.target.id == t.id }
        XCTAssertEqual(job?.strategy, .replaceWithFile, "opt-in keeps the lock on schedule")
    }

    // MARK: - Mutex not leaked on the empty-workload path

    func test_performScheduledClean_emptyWorkloadDoesNotLeakMutex() {
        let scheduler = SchedulerService()
        let state = AppState(persistenceURL: tempURL) // no enabled targets
        scheduler.attachStateForTesting(state)

        scheduler.performScheduledClean()

        XCTAssertFalse(state.isCurrentlyCleaning, "empty workload must not acquire the mutex")
        XCTAssertTrue(state.beginCleaningIfIdle(), "mutex must remain acquirable")
        state.endCleaning()
    }

    /// Drives the *real* async clean→complete path (with a spy back-end and a
    /// silent all-success workload, so no UNUserNotificationCenter call fires)
    /// and asserts the mutex is released and results recorded on completion —
    /// the failure mode centralizing the mutex risked (a stuck-true flag would
    /// block every future clean forever).
    func test_performScheduledClean_releasesMutexAndRecordsResultsOnCompletion() {
        let spy = SpyCleaner()
        let scheduler = SchedulerService(cleaner: spy)
        let state = AppState(persistenceURL: tempURL)
        state.setDefaultTargets(for: .basic)
        state.notificationStyle = .silent // avoid notification delivery in the test bundle
        scheduler.attachStateForTesting(state)

        let released = expectation(description: "mutex released after completion")
        func poll() {
            if !state.isCurrentlyCleaning {
                released.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: poll)
            }
        }

        scheduler.performScheduledClean()
        XCTAssertTrue(state.isCurrentlyCleaning, "mutex should be held while the clean runs")
        poll()
        wait(for: [released], timeout: 5)

        XCTAssertFalse(state.isCurrentlyCleaning, "mutex must be released after a completed run")
        XCTAssertEqual(state.cleaningHistory.count, PrivacyTarget.basicTargets.count,
                       "every job's result should be recorded")
        XCTAssertNotNil(scheduler.nextCleanDate, "next clean date should be set after a run")
        XCTAssertEqual(spy.receivedJobCount, PrivacyTarget.basicTargets.count)
    }
}

/// Records the jobs it was handed and returns all-success results without
/// touching the filesystem.
private final class SpyCleaner: CleaningEngine {
    var receivedJobCount = 0
    func cleanAll(jobs: [CleaningJob]) -> [CleaningResult] {
        receivedJobCount = jobs.count
        return jobs.map {
            CleaningResult(targetID: $0.target.id, strategy: $0.strategy, bytesReclaimed: 0, success: true)
        }
    }
}
