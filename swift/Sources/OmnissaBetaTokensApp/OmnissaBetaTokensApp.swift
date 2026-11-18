import SwiftUI
import AppKit

@main
struct OmnissaBetaTokensApp: App {
    @StateObject private var model = AppModel()

    init() { Brand.registerFonts() }

    var body: some Scene {
        WindowGroup("Omnissa Beta Token Utility") {
            ContentView()
                .environmentObject(model)
                // 520 so left-half split fits laptop visible frames (Open Apple Business).
                .frame(minWidth: 520, minHeight: 560)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentMinSize)
    }
}
