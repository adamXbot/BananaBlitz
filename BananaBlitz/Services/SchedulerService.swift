import Foundation
import UserNotifications
import SwiftUI

/// Manages periodic automated cleaning based on user-configured schedule.
class SchedulerService: ObservableObject {
    @Published var nextCleanDate: Date?
    @Published var isActive: Bool = false

    private var timer: Timer?
    private weak var appState: AppState?
    private let cleaner = PrivacyCleaner.shared

    // MARK: - Configuration

    /// Wire up with the app state and start scheduling.
    func configure(with state: AppState) {
        self.appState = state
        requestNotificationPermission()
        updateSchedule()
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

        timer = Timer.scheduledTimer(withTimeInterval: interval.rawValue, repeats: true) { [weak self] _ in
            self?.performScheduledClean()
        }
    }

    /// Stop all scheduled cleaning.
    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        nextCleanDate = nil
    }

    // MARK: - Cleaning

    /// Execute a scheduled clean of all enabled targets.
    func performScheduledClean() {
        guard let state = appState else { return }

        DispatchQueue.main.async {
            state.isCurrentlyCleaning = true
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let results = self.cleaner.cleanAll(state: state)

            DispatchQueue.main.async {
                for result in results {
                    state.addResult(result)
                }
                state.isCurrentlyCleaning = false
                self.nextCleanDate = Date().addingTimeInterval(state.scheduleInterval.rawValue)

                // Send notification
                if state.notificationStyle != .silent {
                    self.sendCleanNotification(results: results, state: state)
                }
            }
        }
    }

    /// Execute a manual "Blitz Now" clean.
    func performManualClean(completion: @escaping ([CleaningResult]) -> Void) {
        guard let state = appState else { return }

        DispatchQueue.main.async {
            state.isCurrentlyCleaning = true
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let results = self.cleaner.cleanAll(state: state)

            DispatchQueue.main.async {
                for result in results {
                    state.addResult(result)
                }
                state.isCurrentlyCleaning = false

                // Reset next clean timer
                if self.isActive, let state = self.appState {
                    self.nextCleanDate = Date().addingTimeInterval(state.scheduleInterval.rawValue)
                }

                completion(results)
            }
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
        UNUserNotificationCenter.current().add(request)
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
