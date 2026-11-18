import SwiftUI
import AppKit

@main
struct OmnissaBetaTokensApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Omnissa Beta Token Utility") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 760, minHeight: 720)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentMinSize)
    }
}
