import Foundation

/// A throwaway home directory the app under test is pointed at via
/// `CFFIXED_USER_HOME`. Every `~/Library` path the app scans, cleans or locks
/// resolves inside it, so the suite can run a real clean without touching the
/// developer's own `~/Library`. The app refuses to start in UI-testing mode
/// unless its home directory is one of these (see `LaunchConfiguration`).
struct SandboxHome {
    let home: URL
    let library: URL

    private let fileManager = FileManager.default

    init() throws {
        home = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("bananablitz-uitest-\(UUID().uuidString)", isDirectory: true)
        library = home.appendingPathComponent("Library", isDirectory: true)
        for sub in ["Application Support", "Preferences", "Caches", "Logs"] {
            try fileManager.createDirectory(
                at: library.appendingPathComponent(sub, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    /// Where the app persists `state.json` inside this sandbox.
    var stateFile: URL {
        library.appendingPathComponent("Application Support/BananaBlitz/state.json")
    }

    /// Make the app's Full Disk Access probe succeed. `PermissionChecker`
    /// treats a readable `~/Library/Biome` as proof of access.
    func grantFullDiskAccess() throws {
        try fileManager.createDirectory(
            at: library.appendingPathComponent("Biome", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    func url(for fixture: Fixture) -> URL {
        home.appendingPathComponent(fixture.relativePath)
    }

    /// Create the fixture on disk with `files` regular files of `bytesEach`
    /// bytes (directory targets) or a single file of `bytesEach` bytes.
    @discardableResult
    func populate(_ fixture: Fixture, files: Int = 3, bytesEach: Int = 1024) throws -> URL {
        let url = self.url(for: fixture)
        let payload = Data(repeating: 0x41, count: bytesEach)
        if fixture.isFile {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try payload.write(to: url)
        } else {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            for index in 0..<files {
                try payload.write(to: url.appendingPathComponent("fixture-\(index).bin"))
            }
        }
        return url
    }

    func exists(_ fixture: Fixture) -> Bool {
        fileManager.fileExists(atPath: url(for: fixture).path)
    }

    /// Names of the entries inside a directory fixture (empty if absent).
    func contents(of fixture: Fixture) -> [String] {
        (try? fileManager.contentsOfDirectory(atPath: url(for: fixture).path)) ?? []
    }

    /// True when the fixture path has been replaced by a user-immutable file.
    func isLocked(_ fixture: Fixture) -> Bool {
        let url = self.url(for: fixture)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return false
        }
        let values = try? url.resourceValues(forKeys: [.isUserImmutableKey])
        return values?.isUserImmutable ?? false
    }

    /// Remove the sandbox, clearing any immutable flags a lock test left behind
    /// so the delete cannot fail.
    func destroy() throws {
        guard fileManager.fileExists(atPath: home.path) else { return }
        let chflags = Process()
        chflags.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        chflags.arguments = ["-R", "nouchg", home.path]
        try? chflags.run()
        chflags.waitUntilExit()
        try fileManager.removeItem(at: home)
    }
}

/// The subset of the app's target registry the suite creates on disk.
/// `id` and `relativePath` mirror `PrivacyTarget.allTargets`; a mismatch
/// shows up as a failing test, never as a silent no-op.
enum Fixture: String, CaseIterable {
    case adPrivacy = "ad-privacy"
    case amsEngagement = "ams-engagement"
    case feedbackLogger = "feedback-logger"
    case geoAnalytics = "geo-analytics"
    case biome = "biome"
    case suggestions = "suggestions"
    case knowledgeC = "knowledgec"
    case keyboardProfiling = "keyboard-profiling"

    var id: String { rawValue }

    var relativePath: String {
        switch self {
        case .adPrivacy:         return "Library/Caches/com.apple.ap.adprivacyd"
        case .amsEngagement:     return "Library/Caches/com.apple.amsengagementd"
        case .feedbackLogger:    return "Library/Caches/com.apple.feedbacklogger"
        case .geoAnalytics:      return "Library/Caches/com.apple.geoanalyticsd"
        case .biome:             return "Library/Biome"
        case .suggestions:       return "Library/Suggestions"
        case .knowledgeC:        return "Library/Application Support/Knowledge"
        case .keyboardProfiling: return "Library/Keyboard/AutocorrectionRejections.db"
        }
    }

    /// The name the app shows for this target.
    var displayName: String {
        switch self {
        case .adPrivacy:         return "Ad Privacy Daemon"
        case .amsEngagement:     return "AMS Engagement"
        case .feedbackLogger:    return "Feedback Logger"
        case .geoAnalytics:      return "GeoAnalytics"
        case .biome:             return "Biome"
        case .suggestions:       return "Suggestions"
        case .knowledgeC:        return "KnowledgeC"
        case .keyboardProfiling: return "Keyboard Profiling"
        }
    }

    var isFile: Bool { self == .keyboardProfiling }

    /// Basic-level fixtures: enabled at every cleaning level.
    static let basic: [Fixture] = [.adPrivacy, .amsEngagement, .feedbackLogger, .geoAnalytics]
}
