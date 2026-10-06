import AppKit
import SwiftUI

/// Which glyph is shown in the macOS menu bar. The colour banana is the
/// classic brand mark but never adapts to the menu bar's appearance; the
/// monochrome banana and the SF Symbol render as *template* images, so the
/// system tints them black-in-light / white-in-dark (and inverts them while
/// the menu is open) to match the surrounding menu bar.
///
/// The choice is stored by the shared `SurfaceMenuBarPreference`; this enum
/// supplies the ids, titles and images the icon picker and the label use.
enum MenuBarIconStyle: String, CaseIterable, Codable, Identifiable {
    case banana
    case bananaMono
    case sparkles

    var id: String { rawValue }

    static let `default`: MenuBarIconStyle = .bananaMono

    var displayName: String {
        switch self {
        case .banana:     return "Colour"
        case .bananaMono: return "Mono"
        case .sparkles:   return "Sparkles"
        }
    }

    /// The glyph itself, used by the menu bar label and the Settings picker
    /// so both stay in sync.
    var image: Image {
        switch self {
        case .banana:     return Image(nsImage: Self.colourBanana)
        case .bananaMono: return Image(nsImage: Self.monoBananaTemplate)
        case .sparkles:   return Image(systemName: "sparkles")
        }
    }

    // MARK: - Stored preference

    /// The key `SurfaceMenuBarPreference` writes the icon id to, with its
    /// default prefix. Kept here so the legacy migration below targets the
    /// same key.
    static let preferenceKey = "surface.menuBar.icon"

    /// Builds before the shared surfaces stored the icon under
    /// `menuBarIconStyleRaw`. Moves that value to the shared key once, so a
    /// chosen icon survives the upgrade, then removes the old key.
    static func migrateLegacyPreference(in defaults: UserDefaults = .standard) {
        guard let raw = defaults.string(forKey: StorageKey.menuBarIconStyleRaw) else { return }
        if defaults.object(forKey: preferenceKey) == nil, MenuBarIconStyle(rawValue: raw) != nil {
            defaults.set(raw, forKey: preferenceKey)
        }
        defaults.removeObject(forKey: StorageKey.menuBarIconStyleRaw)
    }

    // MARK: - Images

    /// The 🍌 emoji drawn into an image so the picker and the label can show
    /// it the same way. Not a template: it keeps its colour in the menu bar.
    static let colourBanana: NSImage = {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let text = NSAttributedString(string: "🍌", attributes: [.font: NSFont.systemFont(ofSize: 13)])
            let size = text.size()
            text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
            return true
        }
        image.isTemplate = false
        return image
    }()

    /// A monochrome banana drawn as a hollow (outline) *template* `NSImage`, so
    /// a status item tints it black-in-light / white-in-dark and inverts it
    /// while the menu is open — exactly how an SF Symbol behaves — with no asset
    /// to ship. Built once and reused; status items copy it as needed.
    static let monoBananaTemplate: NSImage = {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            // Authored in a 24×24 design space (origin top-left), sized to fill
            // the box with a small margin so the outline reads at menu-bar size,
            // then scaled to the image. The two on-curve points near (20,20)
            // form the rounded lower tip; the path closes at the upper tip.
            let s = side / 24.0
            func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: y * s) }

            let banana = NSBezierPath()
            banana.move(to: p(4.5, 2.9))
            banana.curve(to: p(20.4, 20.0), controlPoint1: p(3.5, 13.5), controlPoint2: p(10.6, 20.8))
            banana.curve(to: p(19.1, 18.2), controlPoint1: p(20.6, 19.1), controlPoint2: p(20.2, 18.4))
            banana.curve(to: p(6.6, 3.9),   controlPoint1: p(11.4, 16.6), controlPoint2: p(6.5, 10.9))
            banana.curve(to: p(4.5, 2.9),   controlPoint1: p(6.5, 2.9),   controlPoint2: p(5.4, 2.2))
            banana.close()

            banana.lineWidth = 1.6
            banana.lineJoinStyle = .round
            banana.lineCapStyle = .round
            NSColor.black.setStroke()
            banana.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
}

/// Renders the chosen base menu bar glyph (without the status badge).
struct MenuBarIconGlyph: View {
    let style: MenuBarIconStyle

    var body: some View {
        style.image
    }
}
