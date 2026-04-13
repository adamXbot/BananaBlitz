import SwiftUI
import Combine

// MARK: - Supporting Enums

/// How notifications are displayed after auto-cleaning.
enum NotificationStyle: String, CaseIterable, Codable, Identifiable {
    case silent
    case summary
    case detailed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .silent:   return "Silent (badge only)"
        case .summary:  return "Summary notification"
        case .detailed: return "Detailed notification"
        }
    }

    var icon: String {
        switch self {
        case .silent:   return "bell.slash"
        case .summary:  return "bell.badge"
        case .detailed: return "bell.badge.fill"
        }
    }
}

/// How frequently targets are automatically cleaned.
enum ScheduleInterval: Double, CaseIterable, Codable, Identifiable {
    case oneHour        = 3600
    case twoHours       = 7200
    case fourHours      = 14400
    case eightHours     = 28800
    case twelveHours    = 43200
    case twentyFourHours = 86400
    case manual         = 0

    var id: Double { rawValue }

    var displayName: String {
        switch self {
        case .oneHour:         return "Every hour"
        case .twoHours:        return "Every 2 hours"
        case .fourHours:       return "Every 4 hours"
        case .eightHours:      return "Every 8 hours"
        case .twelveHours:     return "Every 12 hours"
        case .twentyFourHours: return "Every 24 hours"
        case .manual:          return "Manual only"
        }
    }
}

// MARK: - App State

/// Central observable state for the entire application.
/// Persists user preferences via @AppStorage and complex data via JSON file.
class AppState: ObservableObject {

    // MARK: Simple Preferences (AppStorage)

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("selectedLevelRaw") var selectedLevelRaw: String = CleaningLevel.strong.rawValue
    @AppStorage("scheduleIntervalRaw") var scheduleIntervalRaw: Double = ScheduleInterval.fourHours.rawValue
    @AppStorage("notificationStyleRaw") var notificationStyleRaw: String = NotificationStyle.summary.rawValue
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("isPaused") var isPaused: Bool = false

    // MARK: Published State

    @Published var enabledTargetIDs: Set<String> = []
    @Published var targetStrategies: [String: CleaningStrategy] = [:]
    @Published var cleaningHistory: [CleaningResult] = []
    @Published var lastCleanDate: Date?
    @Published var isCurrentlyCleaning: Bool = false
    @Published var totalBytesReclaimed: Int64 = 0
    @Published var scanResults: [String: Int64] = [:]  // targetID → bytes on disk

    // MARK: Computed Accessors

    var selectedLevel: CleaningLevel {
        get { CleaningLevel(rawValue: selectedLevelRaw) ?? .strong }
        set {
            selectedLevelRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    var scheduleInterval: ScheduleInterval {
        get { ScheduleInterval(rawValue: scheduleIntervalRaw) ?? .fourHours }
        set {
            scheduleIntervalRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    var notificationStyle: NotificationStyle {
        get { NotificationStyle(rawValue: notificationStyleRaw) ?? .summary }
        set {
            notificationStyleRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    /// The currently enabled targets based on user selection.
    var enabledTargets: [PrivacyTarget] {
        PrivacyTarget.allTargets.filter { enabledTargetIDs.contains($0.id) }
    }

    /// Total size across all scanned targets (bytes).
    var totalScannedSize: Int64 {
        scanResults.values.reduce(0, +)
    }

    /// Status label for the menu bar.
    var statusSummary: String {
        guard let last = lastCleanDate else { return "Never cleaned" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Cleaned \(formatter.localizedString(for: last, relativeTo: Date()))"
    }

    // MARK: Init

    init() {
        loadPersistedData()
    }

    // MARK: Actions

    /// Pre-select targets based on the chosen cleaning level.
    func setDefaultTargets(for level: CleaningLevel) {
        let targets = PrivacyTarget.targets(for: level)
        enabledTargetIDs = Set(targets.map(\.id))

        for target in PrivacyTarget.allTargets {
            if targetStrategies[target.id] == nil {
                targetStrategies[target.id] = target.defaultStrategy
            }
        }
        savePersistedData()
    }

    func isTargetEnabled(_ target: PrivacyTarget) -> Bool {
        enabledTargetIDs.contains(target.id)
    }

    func toggleTarget(_ target: PrivacyTarget) {
        if enabledTargetIDs.contains(target.id) {
            enabledTargetIDs.remove(target.id)
        } else {
            enabledTargetIDs.insert(target.id)
        }
        savePersistedData()
    }

    func strategyFor(_ target: PrivacyTarget) -> CleaningStrategy {
        targetStrategies[target.id] ?? target.defaultStrategy
    }

    func setStrategy(_ strategy: CleaningStrategy, for target: PrivacyTarget) {
        targetStrategies[target.id] = strategy
        savePersistedData()
    }

    func addResult(_ result: CleaningResult) {
        cleaningHistory.insert(result, at: 0)
        if cleaningHistory.count > 200 {
            cleaningHistory = Array(cleaningHistory.prefix(200))
        }
        if result.success {
            totalBytesReclaimed += result.bytesReclaimed
            lastCleanDate = result.timestamp
        }
        savePersistedData()
    }

    // MARK: - Persistence (JSON file for complex data)

    private var persistenceURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("BananaBlitz", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    private struct PersistedData: Codable {
        var enabledTargetIDs: Set<String>
        var targetStrategies: [String: CleaningStrategy]
        var cleaningHistory: [CleaningResult]
        var lastCleanDate: Date?
        var totalBytesReclaimed: Int64
    }

    func savePersistedData() {
        let data = PersistedData(
            enabledTargetIDs: enabledTargetIDs,
            targetStrategies: targetStrategies,
            cleaningHistory: cleaningHistory,
            lastCleanDate: lastCleanDate,
            totalBytesReclaimed: totalBytesReclaimed
        )
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: persistenceURL)
        }
    }

    func loadPersistedData() {
        guard let raw = try? Data(contentsOf: persistenceURL),
              let persisted = try? JSONDecoder().decode(PersistedData.self, from: raw)
        else { return }

        enabledTargetIDs    = persisted.enabledTargetIDs
        targetStrategies    = persisted.targetStrategies
        cleaningHistory     = persisted.cleaningHistory
        lastCleanDate       = persisted.lastCleanDate
        totalBytesReclaimed = persisted.totalBytesReclaimed
    }
}
