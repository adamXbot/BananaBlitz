import SwiftUI

/// A colored badge indicating the cleaning level of a target.
struct LevelBadge: View {
    let level: CleaningLevel

    var body: some View {
        Text(level.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(level.color.opacity(0.2))
            .foregroundStyle(level.color)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(level.color.opacity(0.3), lineWidth: 0.5)
            )
    }
}

/// A small dot indicator for status display.
struct StatusDot: View {
    let color: Color
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.5), radius: 3)
    }
}

#Preview {
    VStack(spacing: 12) {
        LevelBadge(level: .basic)
        LevelBadge(level: .strong)
        LevelBadge(level: .paranoid)
        HStack {
            StatusDot(color: .green)
            StatusDot(color: .orange)
            StatusDot(color: .red)
        }
    }
    .padding()
}
