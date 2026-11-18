import SwiftUI
import AppKit
import BetaTokensCore

@MainActor
final class AppModel: ObservableObject {
    let workdir = ServerToken.defaultWorkdir

    @Published var hasKeypair = false
    @Published var p7m: URL?
    @Published var tokens: [BetaToken] = []
    @Published var isLoading = false
    @Published var message: String?
    @Published var errorText: String?
    @Published var search = ""
    @Published var osFilter = "All"
    @Published var selection: BetaToken.ID?
    @Published var revealToken = false
    @Published var mode: EnrollmentMode = .automatic

    init() { refresh() }

    func refresh() {
        hasKeypair = ServerToken.hasKeypair(in: workdir)
        if p7m == nil { p7m = ServerToken.findP7M(in: workdir) }
    }

    func createCertificate() {
        errorText = nil
        do {
            try ServerToken.generateKeypair(in: workdir)
            message = "Certificate created. Upload the .pem to Apple Business, then download the .p7m."
            refresh()
            revealCertificate()
        } catch { errorText = error.localizedDescription }
    }

    static let appleAddServiceURL = URL(string: "https://business.apple.com/main/devices/managementservices/mdmservers/add")!

    /// Apple's form cannot be prefilled from a URL, so the name goes on the clipboard to paste.
    static let serviceName = "Workspace One Beta Token Service"

    func copyServiceName() {
        copy(Self.serviceName, note: "Service name copied. Paste it into the Service Name field in Apple Business.")
    }

    func openAppleBusiness() {
        copyServiceName()
        NSWorkspace.shared.open(Self.appleAddServiceURL)
    }

    func revealCertificate() {
        NSWorkspace.shared.activateFileViewerSelecting([workdir.appendingPathComponent(ServerToken.certName)])
    }

    func fetch() {
        guard let p7m else { return }
        isLoading = true
        errorText = nil
        message = nil
        let wd = workdir
        Task {
            do {
                let creds = try await Task.detached { try ServerToken.decrypt(p7m: p7m, workdir: wd) }.value
                let expired = creds.isAccessTokenExpired
                if expired {
                    errorText = "The Apple Business server token expired" +
                        (creds.accessTokenExpiry.isEmpty ? "" : " (\(creds.accessTokenExpiry))") +
                        ". Regenerate the .p7m in Apple Business, then choose the new file."
                }
                let result = try await ABMClient().fetchBetaTokens(creds)
                tokens = result
                selection = nil
                if expired {
                    message = "Loaded \(result.count) beta programs, but the server token is expired — regenerate the .p7m in Apple Business."
                } else {
                    message = "Loaded \(result.count) beta programs."
                }
            } catch {
                tokens = []
                errorText = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Securely delete local key/cert/*.p7m and clear in-memory tokens.
    /// Caller must confirm first. Reminds the user to remove the ABM management service.
    func teardownLocalCredentials() {
        errorText = nil
        do {
            _ = try ServerToken.teardown(in: workdir)
            p7m = nil
            tokens = []
            selection = nil
            refresh()
            message = "Deleted local key, certificate, and .p7m files. " +
                "Also delete the \"\(Self.serviceName)\" management service in Apple Business if you no longer need it."
        } catch {
            errorText = error.localizedDescription
        }
    }

    func copyForUEM(_ token: BetaToken) {
        let block = Render.uemClipboardBlock(title: token.title, token: token.token, mode: mode)
        copy(block, note: "UEM paste block copied (title, token, and field checklist).")
    }

    var osOptions: [String] {
        ["All"] + Array(Set(tokens.map(\.osDisplay))).sorted { $0.lowercased() < $1.lowercased() }
    }

    var filtered: [BetaToken] {
        Render.filter(tokens, os: osFilter == "All" ? nil : osFilter, text: search)
    }

    var selected: BetaToken? { tokens.first { $0.id == selection } }

    func copy(_ string: String, note: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        message = note
    }
}
