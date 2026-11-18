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
    @Published var isWatchingDownloads = false
    @Published var message: String?
    @Published var errorText: String?
    @Published var search = ""
    @Published var osFilter = "All"
    @Published var selection: BetaToken.ID?
    @Published var revealToken = false

    private var downloadsWatchTask: Task<Void, Never>?
    private var pasteboardClearTask: Task<Void, Never>?

    /// Seconds before a copied enrollment token is cleared from the pasteboard.
    static let tokenPasteboardTTL: UInt64 = 60

    var certificateURL: URL { workdir.appendingPathComponent(ServerToken.certName) }

    init() { refresh() }

    func refresh() {
        hasKeypair = ServerToken.hasKeypair(in: workdir)
        if hasKeypair { ServerToken.hardenCredentials(in: workdir) }
        if p7m == nil { p7m = ServerToken.findP7M(in: workdir) }
        else { ServerToken.hardenCredentials(in: workdir) }
    }

    func createCertificate() {
        errorText = nil
        do {
            try ServerToken.generateKeypair(in: workdir)
            // New cert cannot decrypt an old .p7m — clear selection and watch Downloads.
            p7m = nil
            tokens = []
            selection = nil
            message = "Certificate created. Upload the .pem to Apple Business, then download the .p7m — watching Downloads…"
            refresh()
            revealCertificate()
            startWatchingDownloads()
        } catch { errorText = error.localizedDescription }
    }

    /// Watch ~/Downloads for a new `.p7m`, wait until download finishes, copy into workdir.
    /// Callers: ContentView step 2; createCertificate. User: watch Downloads and move .p7m.
    func startWatchingDownloads() {
        downloadsWatchTask?.cancel()
        isWatchingDownloads = true
        errorText = nil
        let downloads = ServerToken.downloadsDirectory
        let baseline = ServerToken.p7mPaths(in: downloads)
        message = "Watching \(downloads.path) for a new .p7m…"
        let wd = workdir
        downloadsWatchTask = Task { [weak self] in
            while !Task.isCancelled {
                let current = ServerToken.p7mPaths(in: downloads)
                if let newest = current.subtracting(baseline).max(by: {
                    let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return a < b
                }) {
                    do {
                        try await ServerToken.waitUntilDownloadStable(newest)
                        let dest = try ServerToken.importP7M(newest, into: wd)
                        await MainActor.run {
                            guard let self, !Task.isCancelled else { return }
                            self.p7m = dest
                            self.isWatchingDownloads = false
                            self.message = "Server token ready — imported \(dest.lastPathComponent) from Downloads. You can Fetch beta tokens."
                            self.downloadsWatchTask = nil
                        }
                        return
                    } catch is CancellationError {
                        return
                    } catch {
                        await MainActor.run {
                            guard let self else { return }
                            self.isWatchingDownloads = false
                            self.errorText = error.localizedDescription
                            self.downloadsWatchTask = nil
                        }
                        return
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            await MainActor.run {
                self?.isWatchingDownloads = false
                self?.downloadsWatchTask = nil
            }
        }
    }

    func stopWatchingDownloads() {
        downloadsWatchTask?.cancel()
        downloadsWatchTask = nil
        isWatchingDownloads = false
        if message?.contains("Watching") == true {
            message = "Stopped watching Downloads."
        }
    }

    static let appleAddServiceURL = URL(string: "https://business.apple.com/main/devices/managementservices/mdmservers/add")!

    /// Apple's form cannot be prefilled from a URL, so the name goes on the clipboard to paste.
    static let serviceName = "Workspace One Beta Token Service"

    func copyServiceName() {
        copy(Self.serviceName, note: "Service name copied. Paste it into the Service Name field in Apple Business.")
    }

    /// Open Apple Business Add Service; slide this app to the left half (no browser control).
    func openAppleBusiness() {
        copyServiceName()
        SplitScreen.tileAppLeft()
        SplitScreen.openURL(Self.appleAddServiceURL)
        message = "Service name copied; Apple Business opened. This app is on the left — put the browser on the right (macOS window tiling or drag). Paste the name and drag the .pem onto Upload Certificate. Apple will show 0 devices on this service; that is expected."
    }

    func revealCertificate() {
        // Stage only the public cert in a temp folder so Finder never shows mdm_private.key.
        do {
            ServerToken.hardenCredentials(in: workdir)
            let staged = try ServerToken.stagingCertificateForFinder(from: workdir)
            NSWorkspace.shared.activateFileViewerSelecting([staged])
            message = "Certificate ready in Finder — drag \(ServerToken.certName) onto Upload Certificate (private key stays hidden)."
        } catch {
            errorText = error.localizedDescription
        }
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
                // Prefer a supported program for the current OS filter; otherwise first result.
                let preferred = Render.filter(result, os: osFilter == "All" ? nil : osFilter, text: search)
                    .first { !$0.isUnsupportedBetaPlatform }
                    ?? result.first { !$0.isUnsupportedBetaPlatform }
                    ?? result.first
                selection = preferred?.id
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
        stopWatchingDownloads()
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

    func copyTitle(_ token: BetaToken) {
        copy(token.title, note: "Title copied. Use this as the UEM profile name and Beta Description — one profile per AppleSeed program.")
    }

    func copyToken(_ token: BetaToken) {
        copy(
            token.token,
            note: "Token copied — paste into UEM Beta Token within \(Self.tokenPasteboardTTL)s (clipboard then clears).",
            clearAfterSeconds: Self.tokenPasteboardTTL
        )
    }

    /// Hide revealed tokens when the window resigns key (shoulder-surfing / screen-share).
    func concealSensitiveUI() {
        revealToken = false
    }

    var osOptions: [String] {
        ["All"] + Array(Set(tokens.map(\.osDisplay))).sorted { $0.lowercased() < $1.lowercased() }
    }

    var filtered: [BetaToken] {
        Render.filter(tokens, os: osFilter == "All" ? nil : osFilter, text: search)
    }

    var selected: BetaToken? { tokens.first { $0.id == selection } }

    func copy(_ string: String, note: String, clearAfterSeconds: UInt64? = nil) {
        pasteboardClearTask?.cancel()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        message = note
        guard let clearAfterSeconds else { return }
        let snapshot = string
        pasteboardClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: clearAfterSeconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            if NSPasteboard.general.string(forType: .string) == snapshot {
                NSPasteboard.general.clearContents()
                if message?.contains("clipboard then clears") == true {
                    message = "Clipboard cleared (token TTL elapsed)."
                }
            }
        }
    }
}
