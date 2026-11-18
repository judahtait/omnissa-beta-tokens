import Foundation

public enum ProgramEnrollment: String, CaseIterable, Sendable {
    case allowed = "Allowed", alwaysOn = "AlwaysOn", alwaysOff = "AlwaysOff"
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
    public static func declaration(for token: BetaToken, enrollment: ProgramEnrollment = .allowed,
                                   requireProgram: Bool = true) -> String {
        let program: [String: Any] = ["Description": token.title, "Token": token.token]
        var beta: [String: Any] = ["ProgramEnrollment": enrollment.rawValue]
        if requireProgram { beta["RequireProgram"] = program } else { beta["OfferPrograms"] = [program] }
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
