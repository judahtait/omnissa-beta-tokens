import Foundation

/// Client for the Apple Business / Apple School Manager ADE web service.
public struct ABMClient: Sendable {
    public static let sessionURL = "https://mdmenrollment.apple.com/session"
    public static let tokensURL = "https://mdmenrollment.apple.com/os-beta-enrollment/tokens"

    /// Injectable transport so tests never hit the network.
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, Int)
    private let transport: Transport

    public init(transport: @escaping Transport = ABMClient.liveTransport) {
        self.transport = transport
    }

    public static let liveTransport: Transport = { request in
        do {
            let (data, resp) = try await URLSession.shared.data(for: request)
            return (data, (resp as? HTTPURLResponse)?.statusCode ?? 0)
        } catch {
            throw ToolError("Network error contacting Apple: \(error.localizedDescription)")
        }
    }

    public func sessionToken(_ creds: Credentials) async throws -> String {
        var req = URLRequest(url: URL(string: Self.sessionURL)!)
        req.setValue(OAuth1.header(method: "GET", url: Self.sessionURL, credentials: creds), forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, status) = try await transport(req)
        guard status == 200 else {
            throw ToolError("Session request failed (HTTP \(status)). The server token may be expired or revoked; generate a new one in Apple Business.")
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = obj["auth_session_token"] as? String, !token.isEmpty
        else { throw ToolError("auth_session_token missing in session response.") }
        return token
    }

    public func betaTokens(session: String) async throws -> [BetaToken] {
        var req = URLRequest(url: URL(string: Self.tokensURL)!)
        req.setValue(session, forHTTPHeaderField: "X-ADM-Auth-Session")
        req.setValue("1", forHTTPHeaderField: "X-Server-Protocol-Version")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, status) = try await transport(req)
        if status == 403, String(decoding: data, as: UTF8.self).contains("APPLE_SEED_FOR_IT_TURNED_OFF") {
            throw ToolError("Beta access is turned off for this organization (APPLE_SEED_FOR_IT_TURNED_OFF). Enroll the organization in AppleSeed for IT at https://beta.apple.com/for-it and retry.")
        }
        guard status == 200 else { throw ToolError("Beta token request failed (HTTP \(status)).") }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = obj["betaEnrollmentTokens"] as? [[String: Any]]
        else { throw ToolError("Unexpected beta token response.") }
        return items.compactMap {
            guard let t = $0["title"] as? String, let o = $0["os"] as? String, let k = $0["token"] as? String else { return nil }
            return BetaToken(title: t, os: o, token: k)
        }
    }

    public func fetchBetaTokens(_ creds: Credentials) async throws -> [BetaToken] {
        try await betaTokens(session: try await sessionToken(creds))
    }
}
