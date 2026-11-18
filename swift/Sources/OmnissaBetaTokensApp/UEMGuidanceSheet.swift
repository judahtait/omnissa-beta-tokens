import SwiftUI
import AppKit

/// Visual walkthrough for creating a declarative Software Update: Settings profile in UEM.
/// Opened from ContentView via **How to create the UEM profile** (replaces clipboard next-steps).
struct UEMGuidanceSheet: View {
    let platform: String
    let programTitle: String
    @Environment(\.dismiss) private var dismiss

    private var steps: [GuidanceStep] {
        [
            GuidanceStep(
                title: "1. Add Profile → pick the platform",
                detail: "In UEM: Resources → Profiles & Baselines → Profiles → Add → Add Profile. Choose Apple \(platform) so this declaration matches the token’s OS.",
                imageName: "01-add-profile-platform"
            ),
            GuidanceStep(
                title: "2. Declarative → Configuration → Device",
                detail: "Set Management Type to Declarative, Declaration Type to Configuration, Context to Device, then Next.",
                imageName: "02-declarative-configuration"
            ),
            GuidanceStep(
                title: "3. Software Update: Settings → Beta",
                detail: "Add Software Update: Settings, turn Beta On. Paste the program title into Description and the token into Token. Name the profile after the program (e.g. “\(programTitle)”). Assign and publish.",
                imageName: "03-software-update-beta"
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create the UEM profile")
                        .font(Brand.font(20, medium: true))
                        .foregroundColor(Brand.navy)
                    Text("Declarative Software Update: Settings for \(platform) — one profile per platform.")
                        .font(Brand.font(13))
                        .foregroundColor(Brand.slate)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(steps) { step in
                        stepBlock(step)
                    }
                    Text("Tip: Copy title and Copy token from the app, then paste into Description and Token. Modes (Automatic / Offer / Block) are set with the UEM Beta fields — not as JSON from this tool.")
                        .font(Brand.font(12))
                        .foregroundColor(Brand.slate)
                        .padding(.bottom, 8)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 720, idealWidth: 820, minHeight: 560, idealHeight: 640)
        .background(Brand.surface)
    }

    private func stepBlock(_ step: GuidanceStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(step.title)
                .font(Brand.font(15, medium: true))
                .foregroundColor(Brand.navy)
            Text(step.detail)
                .font(Brand.font(13))
                .foregroundColor(Brand.text)
                .fixedSize(horizontal: false, vertical: true)
            if let image = bundledImage(step.imageName) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Brand.rule, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            } else {
                Label("Screenshot missing: \(step.imageName).png — rebuild with tools/make_app.sh", systemImage: "photo")
                    .font(Brand.font(12))
                    .foregroundColor(Brand.magenta)
            }
        }
    }

    private func bundledImage(_ name: String) -> NSImage? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: name, withExtension: "png", subdirectory: "Guidance") {
            return NSImage(contentsOf: url)
        }
        let repoFallback = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("assets/guidance/\(name).png")
        if FileManager.default.fileExists(atPath: repoFallback.path) {
            return NSImage(contentsOf: repoFallback)
        }
        return nil
    }
}

private struct GuidanceStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let imageName: String
}
