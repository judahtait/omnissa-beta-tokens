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

    var certificateURL: URL { workdir.appendingPathComponent(ServerToken.certName) }

    init() { refresh() }

    func refresh() {
        hasKeypair = ServerToken.hasKeypair(in: workdir)
        if p7m == nil { p7m = ServerToken.findP7M(in: workdir) }
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
                            self.message = "Imported \(dest.lastPathComponent) from Downloads. You can Fetch beta tokens."
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

    /// Open Apple Business Add Service and tile this app left / browser right.
    func openAppleBusiness() {
        copyServiceName()
        SplitScreen.tileAppLeft()
        SplitScreen.openURLAndTileBrowserRight(Self.appleAddServiceURL)
        message = "Service name copied. Split screen: this app left, Apple Business right — paste the name and drag the .pem onto Upload Certificate. Apple will show 0 devices on this service; that is expected (UEM remains the enrollment server)."
    }

    func revealCertificate() {
        let cert = certificateURL
        guard FileManager.default.fileExists(atPath: cert.path) else {
            errorText = "No certificate yet. Create the certificate first."
            return
        }
        // Select the .pem in Finder so it is ready to drag into Apple Business.
        NSWorkspace.shared.activateFileViewerSelecting([cert])
        message = "Certificate selected in Finder — drag \(ServerToken.certName) onto Upload Certificate in Apple Business."
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

    func copyForUEM(_ token: BetaToken) {
        let block = Render.uemClipboardBlock(
            title: token.title, token: token.token, platform: token.osDisplay)
        copy(
            block,
            note: "UEM next steps + title/token copied. Create one declarative profile for \(token.osDisplay), then paste Description = title, Token = token."
        )
    }

    func copyTitle(_ token: BetaToken) {
        copy(token.title, note: "Program title copied — paste into UEM Beta Description only.")
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
