import Foundation
import os

/// Unified logging for BananaBlitz.
///
/// Use category-scoped loggers instead of `print(...)` so messages flow
/// through Console.app with correct subsystem grouping and privacy hints.
///
///     private let log = AppLog.scheduler
///     log.error("Failed: \(error.localizedDescription, privacy: .public)")
enum AppLog {
    /// The reverse-DNS subsystem identifier all loggers share.
    static let subsystem = "com.bananablitz.app"

    static let app        = Logger(subsystem: subsystem, category: "app")
    static let scheduler  = Logger(subsystem: subsystem, category: "scheduler")
    static let cleaner    = Logger(subsystem: subsystem, category: "cleaner")
    static let guardLog   = Logger(subsystem: subsystem, category: "filesystem-guard")
    static let scanner    = Logger(subsystem: subsystem, category: "scanner")
    static let snapshot   = Logger(subsystem: subsystem, category: "snapshot")
    static let permission = Logger(subsystem: subsystem, category: "permissions")
    static let state      = Logger(subsystem: subsystem, category: "state")
    static let loginItem  = Logger(subsystem: subsystem, category: "login-item")
}
