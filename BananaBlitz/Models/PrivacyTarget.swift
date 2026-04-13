import Foundation

/// A single privacy-infringing target path in ~/Library that can be cleaned.
struct PrivacyTarget: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let path: String
    let level: CleaningLevel
    let sideEffect: String
    let supportedStrategies: [CleaningStrategy]
    let defaultStrategy: CleaningStrategy
    let isSpecificFile: Bool

    /// Expand ~ to the real home directory
    var resolvedPath: String {
        (path as NSString).expandingTildeInPath
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PrivacyTarget, rhs: PrivacyTarget) -> Bool { lhs.id == rhs.id }

    // MARK: - Target Registry

    static let allTargets: [PrivacyTarget] = harmlessTargets + strongTargets + paranoidTargets

    /// Returns all targets that should be enabled for a given cleaning level.
    /// Harmless → harmless only. Strong → harmless + strong. Paranoid → all.
    static func targets(for level: CleaningLevel) -> [PrivacyTarget] {
        switch level {
        case .harmless: return harmlessTargets
        case .strong:   return harmlessTargets + strongTargets
        case .paranoid: return allTargets
        }
    }

    // MARK: - 🟢 Harmless Targets

    static let harmlessTargets: [PrivacyTarget] = [
        PrivacyTarget(
            id: "ad-privacy",
            name: "Ad Privacy Daemon",
            description: "Advertising privacy configuration and tracking cache used by adprivacyd.",
            path: "~/Library/Caches/com.apple.ap.adprivacyd",
            level: .harmless,
            sideEffect: "None — disabling ad tracking is the goal",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "ams-engagement",
            name: "AMS Engagement",
            description: "App Store engagement metrics collected by amsengagementd.",
            path: "~/Library/Caches/com.apple.amsengagementd",
            level: .harmless,
            sideEffect: "None meaningful",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "ams-metrics",
            name: "AMS Metrics",
            description: "Detailed App Store engagement telemetry data.",
            path: "~/Library/Caches/com.apple.AppleMediaServices/Metrics/amsengagementd",
            level: .harmless,
            sideEffect: "None meaningful",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "cloud-telemetry-cache",
            name: "Cloud Telemetry (Cache)",
            description: "iCloud telemetry cache used to track sync behaviour.",
            path: "~/Library/Caches/com.apple.CloudTelemetry",
            level: .harmless,
            sideEffect: "None meaningful",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "cloud-telemetry-logs",
            name: "Cloud Telemetry (Logs)",
            description: "iCloud telemetry log files recording sync and service events.",
            path: "~/Library/Logs/com.apple.CloudTelemetry",
            level: .harmless,
            sideEffect: "None meaningful",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "feedback-logger",
            name: "Feedback Logger",
            description: "System feedback and crash analytics cache.",
            path: "~/Library/Caches/com.apple.feedbacklogger",
            level: .harmless,
            sideEffect: "None meaningful",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "geo-analytics",
            name: "GeoAnalytics",
            description: "Location analytics data collected by geoanalyticsd.",
            path: "~/Library/Caches/com.apple.geoanalyticsd",
            level: .harmless,
            sideEffect: "None meaningful",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "proactive-eventtracker",
            name: "Proactive EventTracker",
            description: "Proactive suggestion event tracking for predictive features.",
            path: "~/Library/Caches/com.apple.proactive.eventtracker",
            level: .harmless,
            sideEffect: "None meaningful",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
    ]

    // MARK: - 🟡 Strong Targets

    static let strongTargets: [PrivacyTarget] = [
        PrivacyTarget(
            id: "biome",
            name: "Biome",
            description: "Stream-based tracker logging app usage, web activity, and notifications to build a \"pattern of life\" model.",
            path: "~/Library/Biome",
            level: .strong,
            sideEffect: "Siri and Spotlight suggestions will degrade",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "intelligence-platform",
            name: "IntelligencePlatform",
            description: "AI knowledge graph mapping your behaviour, contacts, and interaction patterns.",
            path: "~/Library/IntelligencePlatform",
            level: .strong,
            sideEffect: "Apple Intelligence features will degrade",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "knowledgec",
            name: "KnowledgeC",
            description: "Legacy CoreDuet database logging app usage, device lock/unlock, and media playback.",
            path: "~/Library/Application Support/Knowledge",
            level: .strong,
            sideEffect: "Handoff and suggestions will degrade",
            supportedStrategies: [.wipeContents, .replaceWithFile, .deleteDatabases],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "suggestions",
            name: "Suggestions",
            description: "Databases for people, address, and interaction suggestions across the OS.",
            path: "~/Library/Suggestions",
            level: .strong,
            sideEffect: "QuickType and contact suggestions will degrade",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "parsec",
            name: "Parsec",
            description: "Search suggestion engine powering Spotlight remote results and Safari suggestions.",
            path: "~/Library/Caches/com.apple.parsecd",
            level: .strong,
            sideEffect: "Spotlight remote suggestions will be slower",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "duet-expert",
            name: "DuetExpert",
            description: "Machine learning usage prediction cache for battery and app suggestions.",
            path: "~/Library/Caches/com.apple.duetexpertd",
            level: .strong,
            sideEffect: "Battery prediction will be less accurate",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "siri-tts",
            name: "Siri TTS",
            description: "Siri text-to-speech personalisation cache.",
            path: "~/Library/Caches/com.apple.sirittsd",
            level: .strong,
            sideEffect: "Siri voice will be slightly less personalised",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "chrono",
            name: "Chrono",
            description: "Widget suggestion timing data for proactive widget recommendations.",
            path: "~/Library/Caches/com.apple.chrono",
            level: .strong,
            sideEffect: "Widget suggestions will be less relevant",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "differential-privacy",
            name: "Differential Privacy",
            description: "Stores telemetry data processed with differential privacy before being sent to Apple.",
            path: "~/Library/Application Support/DifferentialPrivacy",
            level: .strong,
            sideEffect: "Stops contributing anonymous analytics to Apple",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "sbd",
            name: "SBD (Secure Backup)",
            description: "Cloud sync analytics and logging from the Secure Backup Daemon.",
            path: "~/Library/Caches/com.apple.sbd",
            level: .strong,
            sideEffect: "iCloud sync analytics stop — sync itself unaffected",
            supportedStrategies: [.wipeContents],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
    ]

    // MARK: - 🔴 Paranoid Targets

    static let paranoidTargets: [PrivacyTarget] = [
        PrivacyTarget(
            id: "trial",
            name: "Trial (assistantd)",
            description: "A/B testing experiments and ML model updates managed by triald. Users cannot opt out of these experiments.",
            path: "~/Library/Trial",
            level: .paranoid,
            sideEffect: "Siri/assistant experiments stop; system may re-download models",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "daemon-containers",
            name: "Daemon Containers",
            description: "Container data for system daemons including intelligent routing optimisation.",
            path: "~/Library/Daemon Containers",
            level: .paranoid,
            sideEffect: "Some system routing optimisation may degrade",
            supportedStrategies: [.wipeContents],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "screentime-agent",
            name: "ScreenTime Agent",
            description: "Screen time usage data — sometimes collects even when the feature is disabled in System Settings.",
            path: "~/Library/Application Support/com.apple.ScreenTimeAgent",
            level: .paranoid,
            sideEffect: "Screen Time data lost (desired if feature is disabled)",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "media-analysis",
            name: "Media Analysis",
            description: "Photos ML analysis cache — face detection, object recognition, Live Text indexing.",
            path: "~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches",
            level: .paranoid,
            sideEffect: "Photos search and suggestions will rebuild from scratch",
            supportedStrategies: [.wipeContents],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "keyboard-profiling",
            name: "Keyboard Profiling",
            description: "Tracks every autocorrection you reject — builds a detailed typing profile.",
            path: "~/Library/Keyboard/AutocorrectionRejections.db",
            level: .paranoid,
            sideEffect: "Autocorrect will be slightly less personalised",
            supportedStrategies: [.deleteDatabases],
            defaultStrategy: .deleteDatabases,
            isSpecificFile: true
        ),
        PrivacyTarget(
            id: "aiml-instrumentation",
            name: "AIML Instrumentation",
            description: "Apple AI/ML instrumentation and telemetry collection.",
            path: "~/Library/com.apple.aiml.instrumentation",
            level: .paranoid,
            sideEffect: "None meaningful — purely telemetry",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
        PrivacyTarget(
            id: "duet-expert-center",
            name: "DuetExpertCenter",
            description: "Central ML prediction engine data store for battery and app usage predictions.",
            path: "~/Library/DuetExpertCenter",
            level: .paranoid,
            sideEffect: "Battery and app prediction models will rebuild",
            supportedStrategies: [.wipeContents, .replaceWithFile],
            defaultStrategy: .wipeContents,
            isSpecificFile: false
        ),
    ]
}
