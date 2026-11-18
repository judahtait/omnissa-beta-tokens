import SwiftUI
import AppKit
import UniformTypeIdentifiers
import BetaTokensCore

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var importing = false
    @State private var confirmTeardown = false
    @State private var showUEMGuidance = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    stepCreate
                    stepChoose
                    stepFetch
                    if !model.tokens.isEmpty { results }
                }
                .padding(20)
            }
            .background(GlassBackdrop())
            statusBar
        }
        .dynamicTypeSize(.medium ... .accessibility3)
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [UTType(filenameExtension: "p7m") ?? .data, .data]) { result in
            if case .success(let url) = result {
                model.p7m = url
                model.message = "Server token ready — \(url.lastPathComponent). You can Fetch beta tokens."
            }
        }
        .sheet(isPresented: $showUEMGuidance) {
            UEMGuidanceSheet(programTitle: model.selected?.title ?? "your beta program")
        }
        .onReceive(NotificationCenter.default.publisher(for: .showUEMGuidance)) { _ in
            showUEMGuidance = true
        }
        .confirmationDialog(
            "Delete local credentials?",
            isPresented: $confirmTeardown,
            titleVisibility: .visible
        ) {
            Button("Delete key, cert, and .p7m", role: .destructive) {
                model.teardownLocalCredentials()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This securely deletes the private key, certificate, and any .p7m files in \(model.workdir.path). Also delete the management service in Apple Business if you no longer need it.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().interpolation(.high).frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text("OMNISSA  |  WORKSPACE ONE UEM")
                    .font(Brand.font(11, medium: true)).tracking(1.6).opacity(0.9)
                Text("Beta Token Utility").font(Brand.font(26, medium: true))
                Text("Get Apple beta enrollment tokens for your declarative Software Update profile.")
                    .font(Brand.font(13))
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(Brand.headerGradient)
        .overlay(LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0)],
                                startPoint: .top, endPoint: .center).allowsHitTesting(false))
    }

    // MARK: Steps

    private var stepCreate: some View {
        card(number: 1, title: "Create certificate") {
            Text("Open Apple Business moves this window left and opens the Add Service page in your browser (no special permissions). Name the service, upload the .pem, then download the .p7m. Apple will show 0 devices on this service; that is normal — UEM stays the enrollment server.")
                .font(Brand.font(13)).foregroundColor(Brand.text)
            HStack {
                Text("Service name:").font(Brand.font(12)).foregroundColor(Brand.slate)
                Text(AppModel.serviceName)
                    .font(Brand.mono(12)).textSelection(.enabled)
                Button("Copy name") { model.copyServiceName() }.buttonStyle(SecondaryButtonStyle())
            }
            if model.hasKeypair {
                draggableCertificate
            }
            FlowButtons {
                if model.hasKeypair {
                    Label("Certificate ready", systemImage: "checkmark.circle.fill")
                        .font(Brand.font(13, medium: true))
                        .foregroundColor(Brand.navy)
                    Button("Show in Finder") { model.revealCertificate() }.buttonStyle(SecondaryButtonStyle())
                } else {
                    Button("Create certificate") { model.createCertificate() }.buttonStyle(PrimaryButtonStyle())
                }
                Button("Open Apple Business") { model.openAppleBusiness() }.buttonStyle(SecondaryButtonStyle())
                if model.hasKeypair || model.p7m != nil {
                    Button("Delete local credentials...") { confirmTeardown = true }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    /// Native file icon the admin can drag straight onto Apple Business Upload Certificate.
    private var draggableCertificate: some View {
        let url = model.certificateURL
        return HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(ServerToken.certName)
                    .font(Brand.font(13, medium: true))
                    .foregroundColor(Brand.navy)
                Text("Drag this file onto Upload Certificate in Apple Business")
                    .font(Brand.font(11))
                    .foregroundColor(Brand.slate)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Brand.card.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Brand.indigo.opacity(0.45), lineWidth: 1)
        )
        .onDrag {
            NSItemProvider(contentsOf: url) ?? NSItemProvider()
        }
        .help("Drag \(ServerToken.certName) into the Apple Business upload control")
    }

    private var stepChoose: some View {
        card(number: 2, title: "Choose server token (.p7m)") {
            Text("After you click Download Service Token in Apple Business, the app can watch ~/Downloads, wait until the .p7m finishes, and move it into the work folder.")
                .font(Brand.font(12)).foregroundColor(Brand.slate)
            if let p7m = model.p7m {
                HStack(spacing: 10) {
                    Label("Server token ready", systemImage: "checkmark.circle.fill")
                        .font(Brand.font(13, medium: true))
                        .foregroundColor(Brand.navy)
                    Text(p7m.lastPathComponent)
                        .font(Brand.font(12))
                        .foregroundColor(Brand.slate)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    Button("Choose another...") { importing = true }
                        .buttonStyle(SecondaryButtonStyle())
                    if !model.isWatchingDownloads {
                        Button("Watch Downloads") { model.startWatchingDownloads() }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(10)
                .background(Brand.card.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Brand.indigo.opacity(0.45), lineWidth: 1)
                )
            }
            HStack {
                if model.isWatchingDownloads {
                    ProgressView().controlSize(.small)
                    Text("Watching Downloads…").font(Brand.font(12)).foregroundColor(Brand.slate)
                    Button("Stop") { model.stopWatchingDownloads() }.buttonStyle(SecondaryButtonStyle())
                } else if model.p7m == nil {
                    Button("Watch Downloads") { model.startWatchingDownloads() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Choose file...") { importing = true }.buttonStyle(SecondaryButtonStyle())
                    Text("No file selected")
                        .font(Brand.font(12)).foregroundColor(Brand.slate)
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.pathExtension == "p7m" }) else { return false }
            model.p7m = url
            model.message = "Server token ready — \(url.lastPathComponent). You can Fetch beta tokens."
            return true
        }
    }

    private var stepFetch: some View {
        card(number: 3, title: "Get beta programs") {
            HStack {
                Button("Fetch beta tokens") { model.fetch() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(model.p7m == nil || !model.hasKeypair || model.isLoading)
                if model.isLoading { ProgressView().controlSize(.small) }
            }
        }
    }

    // MARK: Results

    private var results: some View {
        card(number: 4, title: "Choose a program") {
            HStack {
                Picker("OS", selection: $model.osFilter) {
                    ForEach(model.osOptions, id: \.self) { Text($0).tag($0) }
                }.frame(width: 160)
                TextField("Search title", text: $model.search).textFieldStyle(.roundedBorder)
            }
            List(model.filtered, selection: $model.selection) { t in
                HStack {
                    Text(t.title).font(Brand.font(13)).foregroundColor(Brand.text)
                    Spacer()
                    Text(t.osDisplay).font(Brand.font(12)).foregroundColor(Brand.slate)
                }.tag(t.id)
            }
            .scrollContentBackground(.hidden)
            .background(Brand.card.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Brand.rule, lineWidth: 1))
            .frame(minHeight: 160, idealHeight: 220, maxHeight: 360)
            if let t = model.selected { detail(t) }
        }
    }

    private func detail(_ t: BetaToken) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t.title).font(Brand.font(15, medium: true)).foregroundColor(Brand.navy)
            if t.isUnsupportedBetaPlatform {
                Label(
                    "\(t.osDisplay) is not supported: the Beta setting cannot deliver this program via Software Update:Settings.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(Brand.font(12))
                .foregroundColor(Brand.magenta)
                .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top) {
                Text(model.revealToken ? t.token : t.maskedToken)
                    .font(Brand.mono(12)).textSelection(.enabled)
                    .foregroundColor(Brand.navy)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                Toggle("Reveal", isOn: $model.revealToken).toggleStyle(.switch).controlSize(.small)
            }
            Text("Create one declarative Software Update: Settings profile for \(t.osDisplay). Paste title → Description, token → Token.")
                .font(Brand.font(12)).foregroundColor(Brand.slate)
            FlowButtons {
                Button("Copy title") { model.copyTitle(t) }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Copy token") { model.copy(t.token, note: "Token copied — paste into UEM Beta Token only.") }
                    .buttonStyle(PrimaryButtonStyle())
                Button("How to create the UEM profile") { showUEMGuidance = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .foregroundColor(Brand.text)
        .padding(12)
        .glass(12)
    }

    // MARK: Status

    private var statusBar: some View {
        Group {
            if let e = model.errorText {
                Label(e, systemImage: "exclamationmark.triangle.fill")
                    .font(Brand.font(13)).foregroundColor(Brand.magenta)
            } else if let m = model.message {
                Label(m, systemImage: "info.circle")
                    .font(Brand.font(13)).foregroundColor(Brand.slate)
            } else {
                Label("Ready", systemImage: "checkmark.circle")
                    .font(Brand.font(13)).foregroundColor(Brand.slate.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    /// Wraps action buttons when the window is narrow or text is enlarged.
    private struct FlowButtons<Content: View>: View {
        @ViewBuilder var content: () -> Content
        var body: some View {
            // macOS 13+: flexible wrap without a custom Layout type.
            VStack(alignment: .leading, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { content() }
                    VStack(alignment: .leading, spacing: 8) { content() }
                }
            }
        }
    }

    // MARK: Card

    private func card<Content: View>(number: Int, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(number)").font(Brand.font(12, medium: true)).foregroundColor(.white)
                    .frame(width: 22, height: 22).background(Circle().fill(Brand.indigo))
                Text(title).font(Brand.font(15, medium: true)).foregroundColor(Brand.navy)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glass(16)
    }
}
