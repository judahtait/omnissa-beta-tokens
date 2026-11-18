import SwiftUI
import AppKit
import CoreText

// Omnissa brand values: the palette as (light, dark) pairs, Outfit Light and Medium, and the
// Omnissa gradient (navy, indigo, magenta) for the header band.

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(nsColor: NSColor(hex: hex)) }

    /// A color that follows the Mac's light/dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

enum Brand {
    // Palette, light / dark.
    static let accent = Color(light: 0x4A12F0, dark: 0x7050FF)    // buttons, links, selection
    static let heading = Color(light: 0x1C1C20, dark: 0xF2F2F7)   // titles
    static let text = Color(light: 0x1D1D1F, dark: 0xE5E5E7)      // body
    static let muted = Color(light: 0x6E6E73, dark: 0xA1A1A6)     // secondary text
    static let rule = Color(light: 0xD1D1D6, dark: 0x3A3A3C)      // separators
    static let surface = Color(light: 0xF5F5F7, dark: 0x141416)   // window background
    static let card = Color(light: 0xFFFFFF, dark: 0x1E1E21)      // cards, list background
    static let ok = Color(light: 0x248A3D, dark: 0x30D158)        // healthy
    /// Reserved for negative/exception data (and the end of the edge gradient).
    static let magenta = Color(hex: 0xD600FF)

    // Short aliases used by the views.
    static var navy: Color { heading }
    static var indigo: Color { accent }
    static var slate: Color { muted }
    static var tint: Color { rule }
    static var background: Color { surface }

    /// The Omnissa gradient (navy, indigo, magenta) for the header band.
    static let headerGradient = LinearGradient(
        colors: [Color(hex: 0x001E60), Color(hex: 0x4A12F0), Color(hex: 0xD600FF)],
        startPoint: .leading, endPoint: .trailing)
    static let edge = LinearGradient(
        colors: [Color(hex: 0x4A12F0), Color(hex: 0xD600FF)], startPoint: .leading, endPoint: .trailing)

    // Outfit Light and Medium (SIL OFL 1.1, bundled in Contents/Resources/Fonts).
    static let outfitLight = "Outfit-Light"
    static let outfitMedium = "Outfit-Medium"

    /// In-app multiplier (View menu / ⌘+ ⌘−). Combined with Dynamic Type via `relativeTo`.
    static var textScale: CGFloat = 1.0

    /// Brand font that grows with macOS text size (Dynamic Type) and `textScale`.
    static func font(_ size: CGFloat, medium: Bool = false, relativeTo style: Font.TextStyle? = nil) -> Font {
        let scaled = size * max(0.85, min(textScale, 1.6))
        return .custom(
            medium ? outfitMedium : outfitLight,
            size: scaled,
            relativeTo: style ?? textStyle(for: size)
        )
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size * max(0.85, min(textScale, 1.6)), design: .monospaced)
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ...11: return .caption2
        case ...12: return .caption
        case ...13: return .callout
        case ...15: return .body
        case ...18: return .title3
        case ...22: return .title2
        default: return .title
        }
    }

    /// Registers the bundled fonts for this process only; the system font is used if missing.
    @discardableResult
    static func registerFonts() -> Int {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return 0 }
        var count = 0
        for f in files where f.pathExtension == "ttf" {
            if CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil) { count += 1 }
        }
        return count
    }
}

// MARK: - Liquid Glass

/// Liquid Glass surface. Uses the real `glassEffect` when the toolchain provides it (Swift 6.2+
/// with the macOS 26 SDK) and the app runs on macOS 26; otherwise a material with a specular
/// edge, which gives the same frosted look on earlier systems.
struct GlassSurface: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        #if swift(>=6.2)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            materialFallback(content, shape)
        }
        #else
        materialFallback(content, shape)
        #endif
    }

    private func materialFallback(_ content: Content, _ shape: RoundedRectangle) -> some View {
        content
            .background {
                // Card tint over the material keeps light mode white-frosted instead of gray.
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Brand.card.opacity(0.55))
                }
            }
            .overlay(shape.strokeBorder(
                LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.06)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.10), radius: 14, y: 5)
    }
}

extension View {
    func glass(_ radius: CGFloat = 16) -> some View { modifier(GlassSurface(radius: radius)) }
}

/// Soft indigo and magenta light behind the cards, so the glass has something to refract.
struct GlassBackdrop: View {
    var body: some View {
        ZStack {
            Brand.surface
            Circle().fill(Brand.accent.opacity(0.30)).frame(width: 460, height: 460)
                .blur(radius: 100).offset(x: -280, y: -140)
            Circle().fill(Brand.magenta.opacity(0.16)).frame(width: 420, height: 420)
                .blur(radius: 110).offset(x: 320, y: 280)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Brand.font(13, medium: true))
            .padding(.horizontal, 16).padding(.vertical, 7)
            .background(Capsule().fill(enabled ? Brand.accent : Brand.rule))
            .overlay(Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0)],
                                                   startPoint: .top, endPoint: .center)))  // gloss
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Capsule())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Brand.font(13, medium: true))
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Capsule().fill(Brand.card.opacity(0.75)))
            .overlay(Capsule().stroke(enabled ? Brand.accent : Brand.rule, lineWidth: 1))
            .foregroundColor(enabled ? Brand.accent : Brand.muted)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

// MARK: - Text size (in-app)

enum AppTextSize {
    static let storageKey = "uiTextScale"
    static let min: Double = 0.9
    static let max: Double = 1.45
    static let step: Double = 0.1

    static func apply(_ value: Double) {
        let clamped = Swift.min(Self.max, Swift.max(Self.min, value))
        Brand.textScale = CGFloat(clamped)
    }
}
