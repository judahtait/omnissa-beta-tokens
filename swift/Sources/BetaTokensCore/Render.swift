import Foundation

public enum ProgramEnrollment: String, CaseIterable, Sendable {
    case allowed = "Allowed", alwaysOn = "AlwaysOn", alwaysOff = "AlwaysOff"
}

/// The four valid ways to configure the Beta dictionary.
public enum EnrollmentMode: String, CaseIterable, Identifiable, Sendable {
    case automatic, offer, offerAlwaysOn, off

    public var id: String { rawValue }

    public var programEnrollment: ProgramEnrollment {
        switch self {
        case .automatic, .offerAlwaysOn: return .alwaysOn
        case .offer: return .allowed
        case .off: return .alwaysOff
        }
    }

    public var title: String {
        switch self {
        case .automatic: return "Automatic enrollment (AlwaysOn + Require program)"
        case .offer: return "Offer to user (Allowed + Offer programs)"
        case .offerAlwaysOn: return "Offer, no sign-in needed (AlwaysOn + Offer programs)"
        case .off: return "Block and unenroll (AlwaysOff)"
        }
    }

    /// What to set in the UEM Software Update:Settings > Beta payload.
    public var uemSummary: String {
        switch self {
        case .automatic: return "Program enrollment = AlwaysOn, Require program = on, Offer programs = off"
        case .offer: return "Program enrollment = Allowed, Require program = off, Offer programs = on"
        case .offerAlwaysOn: return "Program enrollment = AlwaysOn, Require program = off, Offer programs = on"
        case .off: return "Program enrollment = AlwaysOff, no program"
        }
    }
}

public enum Render {
    public static let softwareUpdateSettings = "com.apple.configuration.softwareupdate.settings"

    public static func filter(_ tokens: [BetaToken], os: String? = nil, text: String? = nil) -> [BetaToken] {
        var out = tokens.sorted {
            ($0.osDisplay.lowercased(), $0.title.lowercased()) < ($1.osDisplay.lowercased(), $1.title.lowercased())
        }
        if let os, !os.isEmpty { out = out.filter { $0.osDisplay.caseInsensitiveCompare(os) == .orderedSame } }
        if let text, !text.isEmpty { out = out.filter { $0.title.localizedCaseInsensitiveContains(text) } }
        return out
    }

    /// Reference Apple declaration. In the UEM console the same values are entered through
    /// Declarative > Configuration > Software Update:Settings > Beta.
    /// Only combinations valid under Apple's softwareupdate.settings schema can be produced:
    /// RequireProgram only with AlwaysOn, never together with OfferPrograms; AlwaysOff carries no program.
    public static func declaration(for token: BetaToken?, mode: EnrollmentMode = .automatic) -> String {
        var beta: [String: Any] = ["ProgramEnrollment": mode.programEnrollment.rawValue]
        if mode != .off, let token {
            let program: [String: Any] = ["Description": token.title, "Token": token.token]
            if mode == .automatic { beta["RequireProgram"] = program } else { beta["OfferPrograms"] = [program] }
        }
        let doc: [String: Any] = [
            "Type": softwareUpdateSettings,
            "Identifier": UUID().uuidString,
            "Payload": ["Beta": beta],
        ]
        let data = try? JSONSerialization.data(withJSONObject: doc, options: [.prettyPrinted, .sortedKeys])
        return data.map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    public static func json(_ tokens: [BetaToken]) -> String {
        let arr = tokens.map { ["title": $0.title, "os": $0.osDisplay, "token": $0.token] }
        let data = try? JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted, .sortedKeys])
        return data.map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }
}
