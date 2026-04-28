import SwiftUI

/// Brand colours, extracted so the literal HSV values aren't duplicated
/// across `CleanButton`, `OnboardingContainerView`, and `CleanStepView`.
extension Color {
    /// The primary BananaBlitz brand colour.
    static let bananaGold = Color(hue: 0.14, saturation: 0.85, brightness: 0.95)

    /// A slightly darker companion used for gradients.
    static let bananaGoldDark = Color(hue: 0.10, saturation: 0.80, brightness: 0.90)
}
