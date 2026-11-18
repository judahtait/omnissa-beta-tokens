import SwiftUI
import AppKit
import CoreText

// Omnissa brand values with Apple Business Manager–aligned interactive blue.
// ABM “Next” fill sampled 2026-11-18 (Screenshot 2.40.07 AM): Display P3 #306FDB
// (= sRGB #0071E3, Apple’s standard ABM / apple.com blue). Prior #3C85E2 was close but washed.

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    /// Display P3 from 0xRRGGBB channel bytes (as stored in a P3 screenshot).
    convenience init(p3Hex: UInt32) {
        self.init(displayP3Red: CGFloat((p3Hex >> 16) & 0xFF) / 255,
                  green: CGFloat((p3Hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(p3Hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(nsColor: NSColor(hex: hex)) }
    init(p3Hex: UInt32) { self.init(nsColor: NSColor(p3Hex: p3Hex)) }

    /// A color that follows the Mac's light/dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

enum Brand {
    // Palette, light / dark.
    /// Primary actions — exact ABM “Next” fill (Display P3 #306FDB / sRGB #0071E3).
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            // Slightly lifted for dark surfaces (still P3-accurate family).
            return NSColor(p3Hex: 0x4B8AE6)
        }
        return NSColor(p3Hex: 0x306FDB)
    })
    /// sRGB twin of the ABM button (gradients / non-P3 contexts).
    static let accentSRGB = Color(hex: 0x0071E3)
    static let heading = Color(light: 0x1C1C20, dark: 0xF2F2F7)   // titles
    static let text = Color(light: 0x1D1D1F, dark: 0xE5E5E7)      // body
    static let muted = Color(light: 0x6E6E73, dark: 0xA1A1A6)     // secondary text
    static let rule = Color(light: 0xD1D1D6, dark: 0x3A3A3C)      // separators
    static let surface = Color(light: 0xF5F5F7, dark: 0x141416)   // window background (ABM-like gray)
    static let card = Color(light: 0xFFFFFF, dark: 0x1E1E21)      // cards, list background
    static let ok = Color(light: 0x248A3D, dark: 0x30D158)        // healthy
    /// Errors, failures, and unsupported-platform warnings (system red).
    static let error = Color(light: 0xD70015, dark: 0xFF453A)
    /// Secondary / Back-style control fill (ABM gray pill).
    static let secondaryFill = Color(light: 0xF2F2F7, dark: 0x3A3A3C)
    /// Legacy Omnissa accent — not for errors (use `error` instead).
    static let magenta = Color(hex: 0xD600FF)
    /// Omnissa navy retained for header depth.
    static let omnissaNavy = Color(hex: 0x001E60)

    // Short aliases used by the views.
    static var navy: Color { heading }
    static var indigo: Color { accent }
    static var slate: Color { muted }
    static var tint: Color { rule }
    static var background: Color { surface }

    /// Header: Omnissa navy → ABM Next blue (P3-accurate end stop).
    static let headerGradient = LinearGradient(
        colors: [Color(hex: 0x001E60), Color(hex: 0x0B5CAD), Color(p3Hex: 0x306FDB)],
        startPoint: .leading, endPoint: .trailing)
    static let edge = LinearGradient(
        colors: [Color(hex: 0x0B5CAD), Color(p3Hex: 0x306FDB)], startPoint: .leading, endPoint: .trailing)

    /// ABM-like control corner radius (Next / Back are rounded rects, not full pills).
    static let controlRadius: CGFloat = 8

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

/// Soft ABM-blue light behind the cards (no magenta wash on the workspace).
struct GlassBackdrop: View {
    var body: some View {
        ZStack {
            Brand.surface
            Circle().fill(Brand.accent.opacity(0.22)).frame(width: 460, height: 460)
                .blur(radius: 100).offset(x: -280, y: -140)
            Circle().fill(Brand.omnissaNavy.opacity(0.10)).frame(width: 420, height: 420)
                .blur(radius: 110).offset(x: 320, y: 280)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Buttons (shaped like ABM Next / Back)

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Brand.controlRadius, style: .continuous)
        configuration.label
            .font(Brand.font(13, medium: true))
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(shape.fill(enabled ? Brand.accent : Brand.rule))
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(shape)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Brand.controlRadius, style: .continuous)
        configuration.label
            .font(Brand.font(13, medium: true))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(shape.fill(Brand.secondaryFill.opacity(enabled ? 1 : 0.5)))
            .foregroundColor(enabled ? Brand.text : Brand.muted)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(shape)
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
