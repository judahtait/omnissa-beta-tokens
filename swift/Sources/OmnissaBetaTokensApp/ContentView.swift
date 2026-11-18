import SwiftUI
import UniformTypeIdentifiers
import BetaTokensCore

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var importing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    stepCreate
                    stepChoose
                    stepFetch
                    if !model.tokens.isEmpty { results }
                    statusLine
                }
                .padding(20)
            }
            .background(GlassBackdrop())
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [UTType(filenameExtension: "p7m") ?? .data, .data]) { result in
            if case .success(let url) = result { model.p7m = url }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("OMNISSA  |  WORKSPACE ONE UEM")
                .font(Brand.font(11, medium: true)).tracking(1.6).opacity(0.9)
            Text("Beta Token Utility").font(Brand.font(26, medium: true))
            Text("Get Apple beta enrollment tokens for your declarative Software Update profile.")
                .font(Brand.font(13))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.vertical, 18)
        .background(Brand.headerGradient)
        .overlay(alignment: .bottom) { Brand.edge.frame(height: 3) }
    }

    // MARK: Steps

    private var stepCreate: some View {
        card(number: 1, title: "Create certificate") {
            Text("In Apple Business go to Devices > Management Services > Add, name the service, and upload the .pem file. Then download the .p7m server token.")
                .font(Brand.font(13)).foregroundColor(Brand.text)
            HStack {
                Text("Service name:").font(Brand.font(12)).foregroundColor(Brand.slate)
                Text(AppModel.serviceName)
                    .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                Button("Copy name") { model.copyServiceName() }.buttonStyle(SecondaryButtonStyle())
            }
            HStack {
                if model.hasKeypair {
                    Label("Certificate ready", systemImage: "checkmark.circle.fill").foregroundColor(Brand.navy)
                    Button("Show in Finder") { model.revealCertificate() }.buttonStyle(SecondaryButtonStyle())
                } else {
                    Button("Create certificate") { model.createCertificate() }.buttonStyle(PrimaryButtonStyle())
                }
                Button("Open Apple Business") { model.openAppleBusiness() }.buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var stepChoose: some View {
        card(number: 2, title: "Choose server token (.p7m)") {
            HStack {
                Button("Choose file...") { importing = true }.buttonStyle(SecondaryButtonStyle())
                Text(model.p7m?.lastPathComponent ?? "No file selected")
                    .font(Brand.font(12)).foregroundColor(Brand.slate).lineLimit(1).truncationMode(.middle)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.pathExtension == "p7m" }) else { return false }
            model.p7m = url
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
            .frame(height: 200)
            if let t = model.selected { detail(t) }
        }
    }

    private func detail(_ t: BetaToken) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t.title).font(Brand.font(15, medium: true)).foregroundColor(Brand.navy)
            HStack {
                Text(model.revealToken ? t.token : t.maskedToken)
                    .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    .foregroundColor(Brand.navy)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Toggle("Reveal", isOn: $model.revealToken).toggleStyle(.switch).controlSize(.small)
                Button("Copy token") { model.copy(t.token, note: "Token copied to clipboard.") }
                    .buttonStyle(PrimaryButtonStyle())
            }
            Divider()
            Text("Workspace ONE UEM Software Update:Settings > Beta").font(Brand.font(12)).foregroundColor(Brand.slate)
            Picker("Mode", selection: $model.mode) {
                ForEach(EnrollmentMode.allCases) { Text($0.title).tag($0) }
            }
            Text("UEM: " + model.mode.uemSummary).font(Brand.font(12)).foregroundColor(Brand.slate)
            Button("Copy reference declaration (JSON)") {
                model.copy(Render.declaration(for: t, mode: model.mode),
                           note: "Declaration copied to clipboard.")
            }.buttonStyle(SecondaryButtonStyle())
        }
        .foregroundColor(Brand.text)
        .padding(12)
        .glass(12)
    }

    // MARK: Status

    @ViewBuilder private var statusLine: some View {
        if let e = model.errorText {
            // Magenta is reserved for negative/exception data.
            Label(e, systemImage: "exclamationmark.triangle.fill")
                .font(Brand.font(13)).foregroundColor(Brand.magenta)
        } else if let m = model.message {
            Label(m, systemImage: "info.circle").font(Brand.font(13)).foregroundColor(Brand.slate)
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
