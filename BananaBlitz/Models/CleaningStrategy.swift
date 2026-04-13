import Foundation

/// The method used to clean a specific privacy target.
enum CleaningStrategy: String, CaseIterable, Codable, Identifiable {
    case wipeContents
    case replaceWithFile
    case deleteDatabases

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wipeContents:    return "Wipe Contents"
        case .replaceWithFile: return "Lock with Immutable File"
        case .deleteDatabases: return "Delete Databases Only"
        }
    }

    var description: String {
        switch self {
        case .wipeContents:
            return "Delete all files inside the directory. The daemon will recreate them on next run."
        case .replaceWithFile:
            return "Replace the directory with a locked empty file. The daemon cannot recreate its data store. Reversible."
        case .deleteDatabases:
            return "Delete only .db, .sqlite, and .segb files. Least disruptive option."
        }
    }

    var icon: String {
        switch self {
        case .wipeContents:    return "trash"
        case .replaceWithFile: return "lock.fill"
        case .deleteDatabases: return "cylinder.split.1x2"
        }
    }

    var isAggressive: Bool {
        self == .replaceWithFile
    }
}
