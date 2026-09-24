import Foundation

/// The result of a single target cleaning operation.
struct CleaningResult: Identifiable, Codable {
    let id: UUID
    let targetID: String
    let strategy: CleaningStrategy
    let timestamp: Date
    /// Measured: on-disk size before the operation minus size after. Never
    /// assumed from the pre-clean size.
    let bytesReclaimed: Int64
    let success: Bool
    let error: String?
    /// Set on a successful result that deliberately touched nothing (e.g. the
    /// target is locked), so the history does not read as "cleaned". Optional,
    /// and absent from state files written before it existed.
    let note: String?

    init(
        targetID: String,
        strategy: CleaningStrategy,
        timestamp: Date = Date(),
        bytesReclaimed: Int64,
        success: Bool,
        error: String? = nil,
        note: String? = nil
    ) {
        self.id = UUID()
        self.targetID = targetID
        self.strategy = strategy
        self.timestamp = timestamp
        self.bytesReclaimed = bytesReclaimed
        self.success = success
        self.error = error
        self.note = note
    }

    /// Resolve the target name from the target ID
    var targetName: String {
        PrivacyTarget.allTargets.first(where: { $0.id == targetID })?.name ?? targetID
    }
}
