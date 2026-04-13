import Foundation

/// The result of a single target cleaning operation.
struct CleaningResult: Identifiable, Codable {
    let id: UUID
    let targetID: String
    let strategy: CleaningStrategy
    let timestamp: Date
    let bytesReclaimed: Int64
    let success: Bool
    let error: String?

    init(
        targetID: String,
        strategy: CleaningStrategy,
        timestamp: Date = Date(),
        bytesReclaimed: Int64,
        success: Bool,
        error: String? = nil
    ) {
        self.id = UUID()
        self.targetID = targetID
        self.strategy = strategy
        self.timestamp = timestamp
        self.bytesReclaimed = bytesReclaimed
        self.success = success
        self.error = error
    }

    /// Resolve the target name from the target ID
    var targetName: String {
        PrivacyTarget.allTargets.first(where: { $0.id == targetID })?.name ?? targetID
    }
}
