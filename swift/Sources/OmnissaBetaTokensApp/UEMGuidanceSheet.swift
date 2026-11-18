import SwiftUI
import AppKit

/// Click-through steps 1 → 2 → 3 for creating a declarative Software Update profile in UEM.
struct UEMGuidanceSheet: View {
    let platform: String
    let programTitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var stepIndex = 0

    private var steps: [GuidanceStep] {
        [
            GuidanceStep(
                number: 1,
                title: "Add Profile → pick the platform",
                detail: "Resources → Profiles & Baselines → Profiles → Add → Add Profile. Choose Apple \(platform) (match the token’s OS).",
                imageName: "01-add-profile-platform"
            ),
            GuidanceStep(
                number: 2,
                title: "Declarative → Configuration → Device",
                detail: "Set Management Type to Declarative, Declaration Type to Configuration, Context to Device, then Next.",
                imageName: "02-declarative-configuration"
            ),
            GuidanceStep(
                number: 3,
                title: "Software Update: Settings → Beta",
                detail: "Turn Beta On. Use the copied program title as the UEM profile name and paste it into Description; paste the token into Token. Example title: “\(programTitle)”. Assign and publish.",
                imageName: "03-software-update-beta"
            ),
        ]
    }

    private var step: GuidanceStep { steps[stepIndex] }
    private var isLast: Bool { stepIndex >= steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            stepChrome
            Divider()
            stepBody
            Divider()
            footer
        }
        .frame(minWidth: 760, idealWidth: 860, minHeight: 580, idealHeight: 680)
        .background(Brand.surface)
    }

    private var header: some View {
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
            Button("Close") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }

    private var stepChrome: some View {
        HStack(spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, s in
                Button {
                    stepIndex = index
                } label: {
                    HStack(spacing: 6) {
                        Text("\(s.number)")
                            .font(Brand.font(12, medium: true))
                            .foregroundColor(index == stepIndex ? .white : Brand.navy)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(index == stepIndex ? Brand.indigo : Brand.rule.opacity(0.5)))
                        Text("Step \(s.number)")
                            .font(Brand.font(13, medium: index == stepIndex))
                            .foregroundColor(index == stepIndex ? Brand.navy : Brand.slate)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(index == stepIndex ? Brand.card : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(index == stepIndex ? Brand.indigo.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                if index < steps.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Brand.slate)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var stepBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(step.title)
                    .font(Brand.font(16, medium: true))
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
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack {
            if stepIndex > 0 {
                Button("Back") { stepIndex -= 1 }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.leftArrow, modifiers: [])
            }
            Spacer()
            Text("\(stepIndex + 1) of \(steps.count)")
                .font(Brand.font(12))
                .foregroundColor(Brand.slate)
            Spacer()
            if isLast {
                Button("Done") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Next") { stepIndex += 1 }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.rightArrow, modifiers: [])
            }
        }
        .padding(16)
    }

    private func bundledImage(_ name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Guidance") {
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

private struct GuidanceStep {
    let number: Int
    let title: String
    let detail: String
    let imageName: String
}
