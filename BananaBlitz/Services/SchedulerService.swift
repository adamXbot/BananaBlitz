import Foundation
import UserNotifications
import AppKit
import SwiftUI

/// Manages periodic automated cleaning based on user-configured schedule.
///
/// Hardened against three real-world failure modes the Timer-only version had:
///   1. Sleep — `Timer.scheduledTimer` doesn't fire while the Mac is asleep.
///      We re-check on `NSWorkspace.didWakeNotification`.
///   2. Relaunch — if the app quits or restarts after the scheduled fire,
///      `lastCleanDate` is compared against `Date()` on `configure(with:)`
///      and an immediate catch-up clean runs if overdue.
///   3. Paused-mid-fire — `performScheduledClean` re-checks `isPaused` at
///      fire time, in case the user paused between schedule and timer fire.
final class SchedulerService: ObservableObject {
    @Published var nextCleanDate: Date?
    @Published var isActive: Bool = false

    private var timer: Timer?
    private weak var appState: AppState?
    private let cleaner: CleaningEngine
    private let log = AppLog.scheduler

    private var wakeObserver: NSObjectProtocol?

    /// `cleaner` is injectable so tests can drive the real clean/complete/
    /// release path with a spy back-end. Production uses the shared cleaner.
    init(cleaner: CleaningEngine = PrivacyCleaner.shared) {
        self.cleaner = cleaner
    }

    deinit {
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Configuration

    /// Wire up with the app state and start scheduling.
    func configure(with state: AppState) {
        self.appState = state
        requestNotificationPermission()
        installWakeObserver()
        catchUpIfOverdue()
        updateSchedule()
    }

    /// Test seam: attach state without installing observers or requesting
    /// notification permission (the latter is unavailable in a logic-test
    /// bundle). Not used in production — production goes through `configure`.
    func attachStateForTesting(_ state: AppState) {
        self.appState = state
    }

    /// Rebuild the timer based on current app state settings.
    func updateSchedule() {
        timer?.invalidate()
        timer = nil

        guard let state = appState, !state.isPaused else {
            isActive = false
            nextCleanDate = nil
            return
        }

        let interval = state.scheduleInterval
        guard interval != .manual else {
            isActive = false
            nextCleanDate = nil
            return
        }

        isActive = true
        nextCleanDate = Date().addingTimeInterval(interval.rawValue)

        let scheduled = Timer.scheduledTimer(withTimeInterval: interval.rawValue, repeats: true) { [weak self] _ in
            self?.performScheduledClean()
        }
        // Allow the timer to fire even while the run loop is in tracking mode.
        RunLoop.main.add(scheduled, forMode: .common)
        timer = scheduled
    }

    /// Stop all scheduled cleaning.
    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        nextCleanDate = nil
    }

    // MARK: - Catch-up

    /// If a scheduled fire was missed (sleep, relaunch, etc.), run immediately.
    private func catchUpIfOverdue() {
        guard let state = appState, !state.isPaused else { return }
        let interval = state.scheduleInterval.rawValue
        guard interval > 0 else { return }

        let last = state.lastCleanDate ?? .distantPast
        let elapsed = Date().timeIntervalSince(last)
        guard elapsed >= interval else { return }

        log.info("Catch-up clean: last=\(last, privacy: .public), elapsed=\(elapsed)s, interval=\(interval)s")
        performScheduledClean()
    }

    // MARK: - Wake Observer

    private func installWakeObserver() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.log.debug("System woke — re-checking schedule")
            self?.catchUpIfOverdue()
            self?.updateSchedule()
        }
    }

    // MARK: - Cleaning

    /// Execute a scheduled clean of all enabled targets.
    /// Called on the main thread (from the run-loop timer).
    func performScheduledClean() {
        guard let state = appState else { return }
        // Re-check pause state at fire time — user may have paused after the
        // timer was scheduled.
        guard !state.isPaused else {
            log.debug("Scheduled fire skipped: paused")
            return
        }

        // Snapshot the workload on the main thread before going to background.
        // Unattended runs have no confirmation gate, so downgrade the
        // destructive "Lock with Immutable File" strategy to a non-destructive
        // wipe unless the user has explicitly opted in.
        let jobs = Self.unattendedJobs(for: state)
        guard !jobs.isEmpty else {
            log.debug("Scheduled fire skipped: no enabled targets")
            return
        }

        guard beginCleaning(state: state, source: "scheduled") else {
            // Another clean is in flight; keep the displayed countdown honest
            // for the next opportunity rather than leaving it in the past.
            nextCleanDate = Date().addingTimeInterval(state.scheduleInterval.rawValue)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let results = self.cleaner.cleanAll(jobs: jobs)

            DispatchQueue.main.async {
                for result in results {
                    state.addResult(result)
                }
                self.finishCleaning(state: state)
                self.nextCleanDate = Date().addingTimeInterval(state.scheduleInterval.rawValue)

                let failures = results.filter { !$0.success }
                if !failures.isEmpty {
                    // Even in `.silent` mode, surface failures — silent
                    // success is fine, but silent failure for a privacy
                    // tool is worse than an unwanted notification.
                    self.sendFailureNotification(failures: failures)
                } else if state.notificationStyle != .silent {
                    self.sendCleanNotification(results: results, state: state)
                }
            }
        }
    }

    /// Execute a manual "Blitz Now" clean.
    ///
    /// `completion` receives an empty array both when nothing was cleaned *and*
    /// when the run was skipped because another clean is already in flight, so
    /// callers that need to distinguish "skipped" should pre-check
    /// `AppState.isCurrentlyCleaning` (as the menu bar does).
    func performManualClean(completion: @escaping ([CleaningResult]) -> Void) {
        guard let state = appState else {
            completion([])
            return
        }

        // Snapshot on main before dispatching.
        let jobs = state.snapshotCleaningJobs()
        guard !jobs.isEmpty else {
            completion([])
            return
        }

        guard beginCleaning(state: state, source: "manual") else {
            completion([])
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let results = self.cleaner.cleanAll(jobs: jobs)

            DispatchQueue.main.async {
                for result in results {
                    state.addResult(result)
                }
                self.finishCleaning(state: state)

                if self.isActive {
                    self.nextCleanDate = Date().addingTimeInterval(state.scheduleInterval.rawValue)
                }

                completion(results)
            }
        }
    }

    private func beginCleaning(state: AppState, source: String) -> Bool {
        // `AppState.isCurrentlyCleaning` is the single source of truth for the
        // mutex, shared with the onboarding first-run clean.
        guard state.beginCleaningIfIdle() else {
            log.debug("\(source, privacy: .public) clean skipped: another clean is already running")
            return false
        }
        return true
    }

    private func finishCleaning(state: AppState) {
        state.endCleaning()
    }

    /// The jobs an unattended run will actually execute: the current workload
    /// snapshot with aggressive locks downgraded unless the user opted in.
    /// Extracted so the snapshot→sanitise→flag wiring is unit-testable without
    /// driving the async clean. **Main-thread only** (reads `@Published` state).
    static func unattendedJobs(for state: AppState) -> [CleaningJob] {
        sanitiseForUnattendedRun(
            state.snapshotCleaningJobs(),
            allowAggressive: state.allowAggressiveScheduledClean
        )
    }

    /// Coerce the destructive `replaceWithFile` ("Lock with Immutable File")
    /// strategy down to a non-destructive `wipeContents` for unattended
    /// (scheduled / catch-up / wake) runs, unless the user has opted in.
    /// Every `replaceWithFile`-capable target also supports `wipeContents`,
    /// so the downgrade is always a valid strategy for the target.
    static func sanitiseForUnattendedRun(_ jobs: [CleaningJob], allowAggressive: Bool) -> [CleaningJob] {
        guard !allowAggressive else { return jobs }
        return jobs.map { job in
            guard job.strategy.isAggressive else { return job }
            return CleaningJob(target: job.target, strategy: .wipeContents)
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] _, error in
            if let error = error {
                self?.log.error("Notification authorisation failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func sendCleanNotification(results: [CleaningResult], state: AppState) {
        let content = UNMutableNotificationContent()
        content.title = "🍌 BananaBlitz"
        content.sound = .default

        let totalBytes = results.reduce(Int64(0)) { $0 + $1.bytesReclaimed }
        let successCount = results.filter(\.success).count
        let failCount = results.count - successCount

        switch state.notificationStyle {
        case .silent:
            return
        case .summary:
            var body = "Cleaned \(successCount) target\(successCount == 1 ? "" : "s")"
            body += " · \(totalBytes.formattedBytes) reclaimed"
            if failCount > 0 {
                body += " · \(failCount) failed"
            }
            content.body = body
        case .detailed:
            let lines = results.prefix(10).map { result in
                let name = result.targetName
                return "\(result.success ? "✓" : "✗") \(name) (\(result.bytesReclaimed.formattedBytes))"
            }
            content.body = lines.joined(separator: "\n")
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.log.error("Failed to deliver notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Always-on alert when a scheduled clean has at least one failure.
    /// Bypasses `notificationStyle` — silent failure is unacceptable for a
    /// privacy tool the user trusts to keep things empty.
    private func sendFailureNotification(failures: [CleaningResult]) {
        let content = UNMutableNotificationContent()
        content.title = "🍌 BananaBlitz — clean failed"
        content.sound = .default
        let names = failures.prefix(3).map { $0.targetName }.joined(separator: ", ")
        let suffix = failures.count > 3 ? " and \(failures.count - 3) more" : ""
        content.body = "Could not clean: \(names)\(suffix). Open BananaBlitz to investigate."

        let request = UNNotificationRequest(
            identifier: "bananablitz.failure.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.log.error("Failed to deliver failure notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Time Formatting

    /// Human-readable string for time until next clean.
    var timeUntilNextClean: String? {
        guard let next = nextCleanDate else { return nil }
        let interval = next.timeIntervalSinceNow
        guard interval > 0 else { return "Imminent" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else {
            return "in \(minutes)m"
        }
    }
}
