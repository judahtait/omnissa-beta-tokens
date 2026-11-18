import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Omnissa brand values (from the Omnissa PowerPoint Toolkit theme). Magenta is reserved
/// for the gradient end and for negative/exception data, never as a default color.
enum Brand {
    static let navy = Color(hex: 0x001E60)
    static let indigo = Color(hex: 0x4A12F0)
    static let text = Color(hex: 0x28334A)
    static let slate = Color(hex: 0x4C6190)
    static let tint = Color(hex: 0xC8C4E2)
    static let background = Color(hex: 0xF6F5FB)
    static let magenta = Color(hex: 0xD600FF)
    static let gradient = LinearGradient(colors: [navy, indigo, magenta], startPoint: .leading, endPoint: .trailing)
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 16).padding(.vertical, 7)
            .background(Capsule().fill(enabled ? Brand.indigo : Brand.tint))
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14).padding(.vertical, 6)
            .overlay(Capsule().stroke(enabled ? Brand.indigo : Brand.tint, lineWidth: 1))
            .foregroundColor(enabled ? Brand.indigo : Brand.tint)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
