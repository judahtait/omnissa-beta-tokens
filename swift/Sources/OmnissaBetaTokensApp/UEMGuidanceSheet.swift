import SwiftUI
import AppKit

/// Click-through steps for creating a declarative Software Update profile in UEM,
/// including Program enrollment / Require / Offer field guidance from Apple’s schema.
struct UEMGuidanceSheet: View {
    let platform: String
    let programTitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var stepIndex = 0

    private var steps: [GuidanceStep] {
        [
            GuidanceStep(
                number: 1,
                title: "Add → Add Profile",
                detail: "Resources → Profiles & Baselines → Profiles → Add → Add Profile. Then choose Apple \(platform) so the declaration matches the token’s OS.",
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
                detail: "Turn Beta On. Paste the program title into Description (and use it as the profile name); paste the token into Token. Example: “\(programTitle)”. Next: set Program enrollment / Require / Offer.",
                imageName: "03-software-update-beta"
            ),
            GuidanceStep(
                number: 4,
                title: "Enable Beta enrollment settings",
                detail: "In the UEM Beta payload, set Program enrollment, Require program, and Offer programs using only the combinations Apple allows. Do not paste declaration JSON — set these fields in the console.",
                imageName: nil
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
        HStack(spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, s in
                Button {
                    stepIndex = index
                } label: {
                    HStack(spacing: 5) {
                        Text("\(s.number)")
                            .font(Brand.font(12, medium: true))
                            .foregroundColor(index == stepIndex ? .white : Brand.navy)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(index == stepIndex ? Brand.indigo : Brand.rule.opacity(0.5)))
                        Text("Step \(s.number)")
                            .font(Brand.font(12, medium: index == stepIndex))
                            .foregroundColor(index == stepIndex ? Brand.navy : Brand.slate)
                    }
                    .padding(.horizontal, 8)
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
            Spacer(minLength: 0)
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

                if step.number == 4 {
                    betaSettingsGuidance
                } else if let name = step.imageName, let image = bundledImage(name) {
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
                } else if let name = step.imageName {
                    Label("Screenshot missing: \(name).png — rebuild with tools/make_app.sh", systemImage: "photo")
                        .font(Brand.font(12))
                        .foregroundColor(Brand.magenta)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Compact Apple schema guidance for UEM Beta fields (ProgramEnrollment / RequireProgram / OfferPrograms).
    private var betaSettingsGuidance: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldCard(
                title: "Program enrollment",
                body: """
                Controls whether the user can manage beta enrollment in Software Update:
                • Allowed — user may enroll via their Apple Account; Offer programs (if set) are also shown.
                • AlwaysOn — org-controlled; user cannot enroll with their Apple Account. Auto-enrolls into Require program if set; otherwise presents Offer programs.
                • AlwaysOff — no beta enrollment; removes the device from any current beta program.
                """
            )
            fieldCard(
                title: "Require program",
                body: """
                Device automatically enrolls in this beta program (Description + Token).
                Only with Program enrollment = AlwaysOn. Do not set Offer programs when Require program is on.
                """
            )
            fieldCard(
                title: "Offer programs",
                body: """
                List of beta programs the user may choose. Only with Allowed or AlwaysOn. Must not be set together with Require program. On unsupervised devices, enrollment is effectively Allowed when this key is used.
                """
            )

            Text("Valid combinations in UEM")
                .font(Brand.font(14, medium: true))
                .foregroundColor(Brand.navy)

            modeRow("Automatic", "AlwaysOn + Require on + Offer off", "Device enrolls in your program; no user Apple Account enrollment.")
            modeRow("Offer to user", "Allowed + Offer on + Require off", "User can use their Apple Account; offered programs also appear.")
            modeRow("Offer, no sign-in", "AlwaysOn + Offer on + Require off", "User picks from offered programs; no Apple Account enrollment.")
            modeRow("Block and unenroll", "AlwaysOff", "Blocks enrollment and removes existing beta enrollment.")

            Text("Do not use Allowed together with Require program — invalid under Apple’s schema. Prefer Automatic (AlwaysOn + Require).")
                .font(Brand.font(12))
                .foregroundColor(Brand.slate)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fieldCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Brand.font(13, medium: true))
                .foregroundColor(Brand.navy)
            Text(body)
                .font(Brand.font(12))
                .foregroundColor(Brand.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Brand.rule, lineWidth: 1)
        )
    }

    private func modeRow(_ name: String, _ fields: String, _ result: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(Brand.font(13, medium: true))
                .foregroundColor(Brand.navy)
            Text(fields)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Brand.indigo)
            Text(result)
                .font(Brand.font(12))
                .foregroundColor(Brand.slate)
        }
        .padding(.vertical, 4)
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
    let imageName: String?
}
