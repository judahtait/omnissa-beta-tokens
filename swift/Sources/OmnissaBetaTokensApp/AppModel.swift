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
    @Published var enrollment: ProgramEnrollment = .allowed
    @Published var requireProgram = true

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
                let result = try await ABMClient().fetchBetaTokens(creds)
                tokens = result
                selection = nil
                message = "Loaded \(result.count) beta programs."
            } catch {
                tokens = []
                errorText = error.localizedDescription
            }
            isLoading = false
        }
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
