import Foundation

/// Mask a secret for display. Secrets are never shown in full.
public func maskSecret(_ value: String, keep: Int = 4) -> String {
    value.count <= keep ? "[REDACTED]" : "[REDACTED]..." + value.suffix(keep)
}

/// OAuth credentials from the Apple Business server token.
/// `description` never includes secrets, so logs and error output stay safe.
public struct Credentials: Sendable, CustomStringConvertible {
    public let consumerKey: String
    public let consumerSecret: String
    public let accessToken: String
    public let accessSecret: String
    public let accessTokenExpiry: String

    public init(consumerKey: String, consumerSecret: String, accessToken: String,
                accessSecret: String, accessTokenExpiry: String = "") {
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.accessToken = accessToken
        self.accessSecret = accessSecret
        self.accessTokenExpiry = accessTokenExpiry
    }

    public var description: String {
        "Credentials(consumerKey: \(maskSecret(consumerKey)), accessToken: \(maskSecret(accessToken)), " +
        "expiry: \(accessTokenExpiry), secrets: [REDACTED])"
    }

    /// True when `accessTokenExpiry` parses as an absolute date strictly before now.
    /// Unparseable or empty expiry returns `false` (do not warn on missing field).
    public var isAccessTokenExpired: Bool {
        Self.accessTokenExpiryIsPast(accessTokenExpiry)
    }

    public static func accessTokenExpiryIsPast(_ raw: String, now: Date = Date()) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let expiry = parseAccessTokenExpiry(trimmed) else { return false }
        return expiry < now
    }

    /// Apple Business commonly uses ISO-8601 with a trailing `Z` (e.g. `2099-01-01T00:00:00Z`).
    public static func parseAccessTokenExpiry(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        if let d = fallback.date(from: raw) { return d }
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return fallback.date(from: raw)
    }
}

public struct BetaToken: Identifiable, Hashable, Sendable, CustomStringConvertible {
    public let title: String
    public let os: String
    public let token: String

    public init(title: String, os: String, token: String) {
        self.title = title
        self.os = os
        self.token = token
    }

    public var id: String { title + "|" + os }

    /// Apple returns legacy identifiers such as "OSX"; show friendly names.
    public var osDisplay: String { os == "OSX" ? "macOS" : os }

    /// UEM Software Update:Settings Beta cannot deliver enrollment for these platforms.
    public var isUnsupportedBetaPlatform: Bool {
        let name = osDisplay.lowercased()
        return name == "tvos" || name == "visionos"
    }

    public var maskedToken: String {
        token.count > 12 ? "\(token.prefix(6))...\(token.suffix(4))" : "[REDACTED]"
    }

    public var description: String { "BetaToken(title: \(title), os: \(os), token: [REDACTED])" }
}

public struct ToolError: Error, LocalizedError, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
