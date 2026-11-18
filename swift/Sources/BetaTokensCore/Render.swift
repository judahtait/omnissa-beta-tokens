import Foundation

public enum ProgramEnrollment: String, CaseIterable, Sendable {
    case allowed = "Allowed", alwaysOn = "AlwaysOn", alwaysOff = "AlwaysOff"
}

/// Valid UEM Beta payload combinations (enter these in the console; no JSON export).
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

    public var usesRequireProgram: Bool { self == .automatic }
    public var usesOfferPrograms: Bool { self == .offer || self == .offerAlwaysOn }

    /// Short Program enrollment / Require / Offer checklist for clipboard paste into UEM.
    public var fieldChecklist: String {
        """
        Program enrollment = \(programEnrollment.rawValue)
        Require program = \(usesRequireProgram ? "on" : "off")
        Offer programs = \(usesOfferPrograms ? "on" : "off")
        """
    }
}

public enum Render {
    public static func filter(_ tokens: [BetaToken], os: String? = nil, text: String? = nil) -> [BetaToken] {
        var out = tokens.sorted {
            ($0.osDisplay.lowercased(), $0.title.lowercased()) < ($1.osDisplay.lowercased(), $1.title.lowercased())
        }
        if let os, !os.isEmpty { out = out.filter { $0.osDisplay.caseInsensitiveCompare(os) == .orderedSame } }
        if let text, !text.isEmpty { out = out.filter { $0.title.localizedCaseInsensitiveContains(text) } }
        return out
    }

    /// Title + token for UEM Beta fields, plus short “create the profile” directions (not declaration JSON).
    public static func uemClipboardBlock(title: String, token: String, platform: String) -> String {
        """
        Program: \(title)
        Token: \(token)

        Create the UEM profile (one declaration per platform):
        1. Resources > Profiles & Baselines > Profiles > Add > Add Profile
        2. Choose Apple \(platform) (must match this token)
        3. Management Type = Declarative, Declaration Type = Configuration, Context = Device
        4. Add Software Update: Settings → Beta = On
        5. Paste Program into Description, Token into Token
        6. Set Program enrollment / Require / Offer per your policy (see the admin guide), then assign and publish
        """
    }

    public static func json(_ tokens: [BetaToken]) -> String {
        let arr = tokens.map { ["title": $0.title, "os": $0.osDisplay, "token": $0.token] }
        let data = try? JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted, .sortedKeys])
        return data.map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }
}
