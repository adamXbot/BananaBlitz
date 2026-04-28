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

// MARK: - Storage Keys

/// Centralised AppStorage keys to avoid drift on rename.
enum StorageKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let onboardingStep         = "onboardingStep"
    static let selectedLevelRaw       = "selectedLevelRaw"
    static let scheduleIntervalRaw    = "scheduleIntervalRaw"
    static let notificationStyleRaw   = "notificationStyleRaw"
    static let launchAtLogin          = "launchAtLogin"
    static let isPaused               = "isPaused"
    static let showMenuBarStatus      = "showMenuBarStatus"
    static let enableKeyboardShortcut = "enableKeyboardShortcut"
    static let globalStrategyRaw      = "globalStrategyRaw"
}

// MARK: - App State

/// Central observable state for the entire application.
/// Persists user preferences via @AppStorage and complex data via JSON file.
class AppState: ObservableObject {

    // MARK: Simple Preferences (AppStorage)

    @AppStorage(StorageKey.hasCompletedOnboarding) var hasCompletedOnboarding: Bool = false
    @AppStorage(StorageKey.selectedLevelRaw)       var selectedLevelRaw: String = CleaningLevel.strong.rawValue
    @AppStorage(StorageKey.scheduleIntervalRaw)    var scheduleIntervalRaw: Double = ScheduleInterval.fourHours.rawValue
    @AppStorage(StorageKey.notificationStyleRaw)   var notificationStyleRaw: String = NotificationStyle.summary.rawValue
    @AppStorage(StorageKey.launchAtLogin)          var launchAtLogin: Bool = false
    @AppStorage(StorageKey.isPaused)               var isPaused: Bool = false
    @AppStorage(StorageKey.showMenuBarStatus)      var showMenuBarStatus: Bool = true
    @AppStorage(StorageKey.enableKeyboardShortcut) var enableKeyboardShortcut: Bool = false
    @AppStorage(StorageKey.globalStrategyRaw)      var globalStrategyRaw: String = CleaningStrategy.wipeContents.rawValue

    // MARK: Published State

    @Published var enabledTargetIDs: Set<String> = []
    @Published var targetStrategies: [String: CleaningStrategy] = [:]
    @Published var cleaningHistory: [CleaningResult] = []
    @Published var lastCleanDate: Date?
    @Published var isCurrentlyCleaning: Bool = false
    @Published var totalBytesReclaimed: Int64 = 0

    /// Cached scan results — `targetID → bytes on disk`. Refreshed by the
    /// scheduler bootstrap and onboarding. Read freely from view bodies.
    @Published var scanResults: [String: Int64] = [:]

    /// Cached lock states — `targetID → isLocked`. Refreshed alongside
    /// `scanResults` so view bodies don't have to hit the filesystem.
    @Published var lockStates: [String: Bool] = [:]

    /// Cached Full Disk Access status. Refreshed via a `.task` poller in views
    /// that need it; never call `PermissionChecker.hasFullDiskAccess()` from
    /// inside a view body.
    @Published var fullDiskAccessGranted: Bool = false

    // MARK: Computed Accessors

    /// `@AppStorage` already publishes on write — no manual `objectWillChange`
    /// dance is required here.
    var selectedLevel: CleaningLevel {
        get { CleaningLevel(rawValue: selectedLevelRaw) ?? .strong }
        set { selectedLevelRaw = newValue.rawValue }
    }

    var scheduleInterval: ScheduleInterval {
        get { ScheduleInterval(rawValue: scheduleIntervalRaw) ?? .fourHours }
        set { scheduleIntervalRaw = newValue.rawValue }
    }

    var notificationStyle: NotificationStyle {
        get { NotificationStyle(rawValue: notificationStyleRaw) ?? .summary }
        set { notificationStyleRaw = newValue.rawValue }
    }

    var globalStrategy: CleaningStrategy {
        get { CleaningStrategy(rawValue: globalStrategyRaw) ?? .wipeContents }
        set {
            globalStrategyRaw = newValue.rawValue
            for target in PrivacyTarget.allTargets where target.supportedStrategies.contains(newValue) {
                targetStrategies[target.id] = newValue
            }
            savePersistedData()
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

    /// `persistenceURL` is overridable for tests so each test can use a
    /// unique temporary file and runs don't share state. Production callers
    /// pass nothing — `AppState.defaultPersistenceURL` resolves to
    /// `~/Library/Application Support/BananaBlitz/state.json`.
    init(persistenceURL: URL? = AppState.defaultPersistenceURL) {
        self.persistenceURL = persistenceURL
        loadPersistedData()
    }

    // MARK: Actions

    /// Pre-select targets based on the chosen cleaning level.
    func setDefaultTargets(for level: CleaningLevel) {
        let targets = PrivacyTarget.targets(for: level)
        enabledTargetIDs = Set(targets.map(\.id))

        for target in PrivacyTarget.allTargets where targetStrategies[target.id] == nil {
            targetStrategies[target.id] = target.defaultStrategy
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

    /// Build a snapshot of the current cleaning workload. **Must be called on
    /// the main thread** before dispatching to a background queue, so the
    /// background work never touches `@Published` state.
    func snapshotCleaningJobs() -> [CleaningJob] {
        enabledTargets.map { target in
            CleaningJob(target: target, strategy: strategyFor(target))
        }
    }

    /// Persist a fresh scan summary in one publish.
    func applyScanSummary(_ summary: ScanSummary) {
        scanResults = summary.sizes
        lockStates = summary.lockStates
    }

    /// Refresh the cached size + lock state for one target (invoked by the
    /// per-row "verify" button without re-scanning everything).
    func refreshTarget(_ target: PrivacyTarget) {
        let size = TargetScanner.shared.targetSize(target)
        let locked = TargetScanner.shared.isLocked(target)
        scanResults[target.id] = size
        lockStates[target.id] = locked
    }

    // MARK: - Persistence (JSON file for complex data)

    private let persistenceURL: URL?

    /// Default production location: `~/Library/Application Support/BananaBlitz/state.json`.
    /// Returns `nil` if Application Support can't be resolved or the directory
    /// can't be created.
    static var defaultPersistenceURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            AppLog.state.error("Could not resolve Application Support directory")
            return nil
        }
        let dir = appSupport.appendingPathComponent("BananaBlitz", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            AppLog.state.error("Failed to create persistence directory: \(error.localizedDescription, privacy: .public)")
            return nil
        }
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
        guard let url = persistenceURL else { return }

        let data = PersistedData(
            enabledTargetIDs: enabledTargetIDs,
            targetStrategies: targetStrategies,
            cleaningHistory: cleaningHistory,
            lastCleanDate: lastCleanDate,
            totalBytesReclaimed: totalBytesReclaimed
        )
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: .atomic)
        } catch {
            AppLog.state.error("Failed to persist state: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadPersistedData() {
        guard let url = persistenceURL,
              let raw = try? Data(contentsOf: url) else { return }

        do {
            let persisted = try JSONDecoder().decode(PersistedData.self, from: raw)
            enabledTargetIDs    = persisted.enabledTargetIDs
            targetStrategies    = persisted.targetStrategies
            cleaningHistory     = persisted.cleaningHistory
            lastCleanDate       = persisted.lastCleanDate
            totalBytesReclaimed = persisted.totalBytesReclaimed
        } catch {
            AppLog.state.error("Failed to decode persisted state: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Clear all user-visible state and persisted data. Caller is responsible
    /// for stopping the scheduler.
    func resetAll() {
        hasCompletedOnboarding = false
        enabledTargetIDs.removeAll()
        targetStrategies.removeAll()
        cleaningHistory.removeAll()
        totalBytesReclaimed = 0
        lastCleanDate = nil
        scanResults.removeAll()
        lockStates.removeAll()
        // Restart the onboarding wizard from step 0.
        UserDefaults.standard.removeObject(forKey: StorageKey.onboardingStep)
        savePersistedData()
    }
}
