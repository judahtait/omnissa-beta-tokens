import Foundation
import CryptoKit

/// OAuth 1.0a (HMAC-SHA1) header for Apple's /session endpoint.
public enum OAuth1 {
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// RFC 3986 percent-encoding.
    public static func urlEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s
    }

    public static func header(method: String, url: String, credentials c: Credentials,
                              timestamp: Int? = nil, nonce: String? = nil) -> String {
        var params: [(String, String)] = [
            ("oauth_consumer_key", c.consumerKey),
            ("oauth_nonce", nonce ?? randomNonce()),
            ("oauth_signature_method", "HMAC-SHA1"),
            ("oauth_timestamp", String(timestamp ?? Int(Date().timeIntervalSince1970))),
            ("oauth_token", c.accessToken),
            ("oauth_version", "1.0"),
        ]
        let paramString = params.sorted { $0.0 < $1.0 }
            .map { "\(urlEncode($0.0))=\(urlEncode($0.1))" }
            .joined(separator: "&")
        let base = [method.uppercased(), url, paramString].map(urlEncode).joined(separator: "&")
        let signingKey = "\(urlEncode(c.consumerSecret))&\(urlEncode(c.accessSecret))"
        let mac = HMAC<Insecure.SHA1>.authenticationCode(
            for: Data(base.utf8), using: SymmetricKey(data: Data(signingKey.utf8)))
        params.append(("oauth_signature", Data(mac).base64EncodedString()))
        return "OAuth realm=\"ADM\"," + params.map { "\($0.0)=\"\(urlEncode($0.1))\"" }.joined(separator: ",")
    }

    private static func randomNonce() -> String {
        (0..<8).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }
}
