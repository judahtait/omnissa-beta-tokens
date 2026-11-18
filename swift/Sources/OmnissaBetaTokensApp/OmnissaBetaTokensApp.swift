import SwiftUI
import AppKit

@main
struct OmnissaBetaTokensApp: App {
    @StateObject private var model = AppModel()
    @AppStorage(AppTextSize.storageKey) private var textScale = 1.0

    init() {
        Brand.registerFonts()
        let stored = UserDefaults.standard.object(forKey: AppTextSize.storageKey) as? Double ?? 1.0
        AppTextSize.apply(stored)
    }

    var body: some Scene {
        WindowGroup("Omnissa Beta Token Utility") {
            ContentView()
                .environmentObject(model)
                // 520 so left-half split fits laptop visible frames (Open Apple Business).
                .frame(minWidth: 520, minHeight: 560)
                .id(textScale) // refresh fonts when in-app scale changes
                .onAppear {
                    AppTextSize.apply(textScale)
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onChange(of: textScale) { newValue in
                    AppTextSize.apply(newValue)
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu("View") {
                Button("Make Text Larger") {
                    textScale = min(AppTextSize.max, textScale + AppTextSize.step)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Make Text Smaller") {
                    textScale = max(AppTextSize.min, textScale - AppTextSize.step)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Text Size") {
                    textScale = 1.0
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("How to Create the UEM Profile") {
                    NotificationCenter.default.post(name: .showUEMGuidance, object: nil)
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let showUEMGuidance = Notification.Name("showUEMGuidance")
}
