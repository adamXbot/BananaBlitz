import XCTest
@testable import BananaBlitz

final class AppStateTests: XCTestCase {

    /// UserDefaults keys we touch from these tests. Cleared in setUp/tearDown
    /// so each test starts from defaults regardless of run order.
    private static let userDefaultsKeysToClear: [String] = [
        StorageKey.hasCompletedOnboarding,
        StorageKey.onboardingStep,
        StorageKey.selectedLevelRaw,
        StorageKey.scheduleIntervalRaw,
        StorageKey.notificationStyleRaw,
        StorageKey.launchAtLogin,
        StorageKey.isPaused,
        StorageKey.showMenuBarStatus,
        StorageKey.menuBarIconStyleRaw,
        StorageKey.enableKeyboardShortcut,
        StorageKey.globalStrategyRaw,
    ]

    private var tempURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Unique JSON file per test so persisted history can't bleed between
        // tests via the default Application Support location.
        tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bananablitz-state-\(UUID().uuidString).json")

        // Clear any UserDefaults state left by previous tests or by the real
        // app running on this machine.
        clearUserDefaults()
    }

    override func tearDownWithError() throws {
        if let url = tempURL {
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            // Remove any `*.corrupt-*` backups left by the corrupt-load test.
            let dir = url.deletingLastPathComponent()
            let prefix = url.lastPathComponent + ".corrupt-"
            if let siblings = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
                for name in siblings where name.hasPrefix(prefix) {
                    try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
                }
            }
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

    /// Convenience factory: every test gets an `AppState` whose JSON
    /// persistence is isolated to its own temporary file.
    private func makeState() -> AppState {
        AppState(persistenceURL: tempURL)
    }

    // MARK: - Tests

    func test_setDefaultTargets_basic() {
        let state = makeState()
        state.setDefaultTargets(for: .basic)
        XCTAssertEqual(state.enabledTargetIDs.count, PrivacyTarget.targets(for: .basic).count)
        XCTAssertTrue(state.enabledTargetIDs.contains("ad-privacy"))
        XCTAssertFalse(state.enabledTargetIDs.contains("biome"))
    }

    func test_setDefaultTargets_paranoidIncludesAll() {
        let state = makeState()
        state.setDefaultTargets(for: .paranoid)
        XCTAssertEqual(state.enabledTargetIDs.count, PrivacyTarget.allTargets.count)
    }

    func test_toggleTarget_flipsMembership() {
        let state = makeState()
        let target = PrivacyTarget.basicTargets[0]

        XCTAssertFalse(state.isTargetEnabled(target))
        state.toggleTarget(target)
        XCTAssertTrue(state.isTargetEnabled(target))
        state.toggleTarget(target)
        XCTAssertFalse(state.isTargetEnabled(target))
    }

    func test_addResult_capsHistoryAt200() {
        let state = makeState()
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
        let state = makeState()
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
        let state = makeState()
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
        let state = makeState()
        state.setDefaultTargets(for: .strong)
        state.totalBytesReclaimed = 12_345
        state.hasCompletedOnboarding = true

        state.resetAll()

        XCTAssertFalse(state.hasCompletedOnboarding)
        XCTAssertTrue(state.enabledTargetIDs.isEmpty)
        XCTAssertEqual(state.totalBytesReclaimed, 0)
        XCTAssertNil(state.lastCleanDate)
    }

    func test_load_preservesUnreadableStateInsteadOfDestroyingIt() throws {
        // A file that exists but won't decode as PersistedData.
        let garbage = Data("this is not valid PersistedData json".utf8)
        try garbage.write(to: tempURL)

        // Loading falls back to defaults without crashing...
        let state = makeState()
        XCTAssertTrue(state.enabledTargetIDs.isEmpty)
        XCTAssertEqual(state.totalBytesReclaimed, 0)

        // ...and preserves the original bytes in a sibling backup.
        let dir = tempURL.deletingLastPathComponent()
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix(tempURL.lastPathComponent + ".corrupt-") }
        XCTAssertEqual(backups.count, 1, "expected exactly one corrupt-state backup")
        let backupURL = dir.appendingPathComponent(backups[0])
        XCTAssertEqual(try Data(contentsOf: backupURL), garbage,
                       "original bytes must be preserved, not destroyed")

        // A subsequent save writes fresh state to the live path and leaves the
        // preserved backup untouched — the original data-loss bug is gone.
        state.setDefaultTargets(for: .basic)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        XCTAssertEqual(try Data(contentsOf: backupURL), garbage)
    }

    func test_load_blocksSaveWhenPriorStateIsUnreadable() throws {
        // A path that exists but can't be read as a state file (here: a
        // directory). loadPersistedData must not crash, and a later save must
        // NOT replace it — overwriting an un-preserved file would silently
        // destroy whatever is there.
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        let state = makeState()
        XCTAssertTrue(state.enabledTargetIDs.isEmpty)

        state.setDefaultTargets(for: .basic) // triggers savePersistedData

        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue, "save must be blocked; the unreadable path must be left intact")
    }

    func test_cleaningMutex_isExclusive() {
        let state = makeState()
        XCTAssertTrue(state.beginCleaningIfIdle(), "first acquire should succeed")
        XCTAssertTrue(state.isCurrentlyCleaning)
        XCTAssertFalse(state.beginCleaningIfIdle(), "second acquire must fail while in flight")
        state.endCleaning()
        XCTAssertFalse(state.isCurrentlyCleaning)
        XCTAssertTrue(state.beginCleaningIfIdle(), "acquire should succeed again after release")
        state.endCleaning()
    }

    func test_menuBarIconStyle_defaultsToMonochromeBanana() {
        let state = makeState()
        XCTAssertEqual(state.menuBarIconStyle, .bananaMono)
    }

    func test_menuBarIconStyle_persistsSelection() {
        let state = makeState()
        state.menuBarIconStyle = .sparkles
        XCTAssertEqual(state.menuBarIconStyle, .sparkles)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: StorageKey.menuBarIconStyleRaw),
            MenuBarIconStyle.sparkles.rawValue
        )
    }

    func test_menuBarIconStyle_unknownRawFallsBackToMonochromeBanana() {
        UserDefaults.standard.set("not-a-real-style", forKey: StorageKey.menuBarIconStyleRaw)
        let state = makeState()
        XCTAssertEqual(state.menuBarIconStyle, .bananaMono)
    }

    func test_persistence_roundTripsAcrossInstances() {
        // Demonstrates the injection: persistedData written by one instance
        // is visible to a fresh instance pointing at the same URL.
        do {
            let writer = makeState()
            writer.setDefaultTargets(for: .basic)
            writer.addResult(CleaningResult(
                targetID: "ad-privacy",
                strategy: .wipeContents,
                bytesReclaimed: 4096,
                success: true
            ))
        }
        let reader = makeState()
        XCTAssertTrue(reader.enabledTargetIDs.contains("ad-privacy"))
        XCTAssertEqual(reader.totalBytesReclaimed, 4096)
        XCTAssertNotNil(reader.lastCleanDate)
    }
}
