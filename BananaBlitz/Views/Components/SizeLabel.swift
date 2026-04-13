import SwiftUI

/// Displays a human-readable byte count (e.g. "142 MB") with optional icon.
struct SizeLabel: View {
    let bytes: Int64
    var showIcon: Bool = false
    var style: SizeLabelStyle = .normal

    enum SizeLabelStyle {
        case normal, compact, prominent
    }

    var body: some View {
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: "internaldrive")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            switch style {
            case .normal:
                Text(bytes.formattedBytes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .compact:
                Text(bytes.formattedBytes)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            case .prominent:
                Text(bytes.formattedBytes)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        SizeLabel(bytes: 142_000_000, style: .prominent)
        SizeLabel(bytes: 142_000_000, showIcon: true)
        SizeLabel(bytes: 1_024, style: .compact)
    }
    .padding()
}
