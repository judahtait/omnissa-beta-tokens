import Darwin
import Foundation

/// Key/cert generation and server token (.p7m) decryption using the system openssl.
/// The decrypted token is held in memory only and never written to disk.
public enum ServerToken {
    public static let keyName = "mdm_private.key"
    public static let certName = "mdm_public_cert.pem"
    public static let certCommonName = "Omnissa Beta Token Utility"

    public static var defaultWorkdir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".omnissa-beta-tokens")
    }

    struct ProcessResult { let status: Int32; let out: Data; let err: Data }

    static var opensslPath: String {
        FileManager.default.isExecutableFile(atPath: "/usr/bin/openssl") ? "/usr/bin/openssl" : "/opt/homebrew/bin/openssl"
    }

    static func runOpenSSL(_ args: [String], input: Data? = nil) throws -> ProcessResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: opensslPath)
        p.arguments = args
        let out = Pipe(), err = Pipe(), inp = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = inp
        do { try p.run() } catch { throw ToolError("Could not run openssl at \(opensslPath): \(error.localizedDescription)") }
        if let input { inp.fileHandleForWriting.write(input) }
        try? inp.fileHandleForWriting.close()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return ProcessResult(status: p.terminationStatus, out: outData, err: errData)
    }

    public static func ensureWorkdir(_ dir: URL) throws {
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
    }

    public static func hasKeypair(in dir: URL) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(keyName).path) &&
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(certName).path)
    }

    @discardableResult
    public static func generateKeypair(in dir: URL, days: Int = 365) throws -> (key: URL, cert: URL) {
        try ensureWorkdir(dir)
        let key = dir.appendingPathComponent(keyName), cert = dir.appendingPathComponent(certName)
        if FileManager.default.fileExists(atPath: key.path) || FileManager.default.fileExists(atPath: cert.path) {
            throw ToolError("A key or certificate already exists in \(dir.path). Remove them to start over.")
        }
        // Match Python: tighten umask before openssl writes the key, then restore.
        let previousUmask = umask(0o177)
        defer { _ = umask(previousUmask) }
        let r = try runOpenSSL(["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-sha256",
                                "-keyout", key.path, "-out", cert.path,
                                "-days", String(days), "-subj", "/CN=\(certCommonName)"])
        guard r.status == 0 else {
            throw ToolError("openssl failed: \(String(decoding: r.err, as: UTF8.self))")
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: key.path)
        return (key, cert)
    }

    public static func findP7M(in dir: URL) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.filter { $0.pathExtension == "p7m" }.max {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a < b
        }
    }

    /// Securely overwrite then delete key, cert, and any `*.p7m` in `dir`.
    /// Returns the paths removed. Throws if nothing was present to delete.
    @discardableResult
    public static func teardown(in dir: URL) throws -> [URL] {
        let fm = FileManager.default
        var targets: [URL] = [
            dir.appendingPathComponent(keyName),
            dir.appendingPathComponent(certName),
        ]
        let listed = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        targets += listed.filter { $0.pathExtension.lowercased() == "p7m" }
        let existing = targets.filter { fm.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else {
            throw ToolError("No key, certificate, or .p7m found in \(dir.path).")
        }
        var removed: [URL] = []
        for url in existing {
            try secureDelete(url)
            removed.append(url)
        }
        return removed
    }

    /// Overwrite file contents with zeros, then unlink. Falls back to unlink-only if overwrite fails.
    static func secureDelete(_ url: URL) throws {
        let fm = FileManager.default
        if let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value,
           size > 0,
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            let chunkSize = 64 * 1024
            var remaining = size
            let zeros = Data(count: chunkSize)
            while remaining > 0 {
                let n = Int(min(UInt64(chunkSize), remaining))
                try handle.write(contentsOf: zeros.prefix(n))
                remaining -= UInt64(n)
            }
            try? handle.synchronize()
        }
        try fm.removeItem(at: url)
    }

    public static func decrypt(p7m: URL, workdir: URL) throws -> Credentials {
        let key = workdir.appendingPathComponent(keyName), cert = workdir.appendingPathComponent(certName)
        for f in [p7m, key, cert] where !FileManager.default.fileExists(atPath: f.path) {
            throw ToolError("Missing file: \(f.path)")
        }
        let base = ["smime", "-decrypt", "-recip", cert.path, "-inkey", key.path]
        var r = try runOpenSSL(base + ["-inform", "SMIME", "-in", p7m.path])
        if r.status != 0 {
            // Fallback matching the original Microsoft script: drop 5 header lines, base64 -> DER.
            if let text = try? String(contentsOf: p7m, encoding: .utf8) {
                let b64 = text.split(separator: "\n", omittingEmptySubsequences: false).dropFirst(5).joined()
                if let der = Data(base64Encoded: b64, options: .ignoreUnknownCharacters), !der.isEmpty {
                    r = try runOpenSSL(base + ["-inform", "DER"], input: der)
                }
            }
        }
        guard r.status == 0 else {
            throw ToolError("Failed to decrypt the .p7m. Does it match the PEM that was uploaded to Apple Business?")
        }
        return try parseCredentials(from: r.out)
    }

    static func parseCredentials(from data: Data) throws -> Credentials {
        let s = String(decoding: data, as: UTF8.self)
        guard let open = s.firstIndex(of: "{"), let close = s.lastIndex(of: "}"), open < close,
              let json = try? JSONSerialization.jsonObject(with: Data(s[open...close].utf8)) as? [String: Any]
        else { throw ToolError("No JSON payload found in decrypted server token.") }
        func field(_ k: String) throws -> String {
            guard let v = json[k] as? String else { throw ToolError("Server token payload is missing \(k).") }
            return v
        }
        return Credentials(consumerKey: try field("consumer_key"), consumerSecret: try field("consumer_secret"),
                           accessToken: try field("access_token"), accessSecret: try field("access_secret"),
                           accessTokenExpiry: json["access_token_expiry"] as? String ?? "")
    }
}
