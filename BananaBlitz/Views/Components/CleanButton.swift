import SwiftUI

/// An animated action button for cleaning operations.
struct CleanButton: View {
    let title: String
    let icon: String
    var isLoading: Bool = false
    var style: CleanButtonStyle = .primary
    let action: () -> Void

    enum CleanButtonStyle {
        case primary, secondary, destructive
    }

    @State private var isHovered = false
    @State private var isPressed = false

    private var backgroundColor: Color {
        switch style {
        case .primary:     return Color(hue: 0.14, saturation: 0.85, brightness: 0.95)  // banana gold
        case .secondary:   return Color(.controlBackgroundColor)
        case .destructive: return .red
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:     return .black
        case .secondary:   return .primary
        case .destructive: return .white
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .symbolEffect(.bounce, value: isPressed)
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: style == .primary ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .opacity(isHovered ? 0.9 : 1.0)
                    .shadow(
                        color: backgroundColor.opacity(isHovered ? 0.4 : 0.2),
                        radius: isHovered ? 8 : 4,
                        y: 2
                    )
            )
            .foregroundStyle(foregroundColor)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 16) {
        CleanButton(title: "Blitz Now", icon: "bolt.fill", action: {})
        CleanButton(title: "Settings", icon: "gear", style: .secondary, action: {})
        CleanButton(title: "Delete All", icon: "trash", style: .destructive, action: {})
        CleanButton(title: "Cleaning...", icon: "bolt.fill", isLoading: true, action: {})
    }
    .padding()
    .frame(width: 300)
}
