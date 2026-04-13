import SwiftUI

/// Represents the aggressiveness of privacy cleaning.
/// Users choose a level during onboarding, which pre-selects which targets to clean.
enum CleaningLevel: String, CaseIterable, Codable, Identifiable {
    case harmless
    case strong
    case paranoid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .harmless: return "Harmless"
        case .strong:   return "Strong"
        case .paranoid: return "Paranoid"
        }
    }

    var emoji: String {
        switch self {
        case .harmless: return "🟢"
        case .strong:   return "🟡"
        case .paranoid: return "🔴"
        }
    }

    var color: Color {
        switch self {
        case .harmless: return .green
        case .strong:   return .orange
        case .paranoid: return .red
        }
    }

    var description: String {
        switch self {
        case .harmless: return "Clean only analytics and metrics. Nothing breaks."
        case .strong:   return "Also clean intelligence databases. Suggestions get dumber."
        case .paranoid: return "Clean everything. Maximum privacy. Some features may temporarily break."
        }
    }

    var icon: String {
        switch self {
        case .harmless: return "shield"
        case .strong:   return "shield.lefthalf.filled"
        case .paranoid: return "shield.fill"
        }
    }

    /// How many targets are included at this level
    var targetCount: Int {
        PrivacyTarget.targets(for: self).count
    }
}
