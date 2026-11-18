import AppKit

/// Positions **this** app on the left half and opens a URL in the default browser.
///
/// We deliberately do **not** resize or script the browser. Controlling another
/// app requires Accessibility / Automation consent (“would like to control this
/// Mac…”). There is no supported way around that on macOS — so Open Apple
/// Business only moves our own window (no TCC prompt) and leaves the browser alone.
enum SplitScreen {
    private static let gap: CGFloat = 8
    private static let minHalfWidth: CGFloat = 520

    static func tileAppLeft() {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible) else { return }
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
        window.minSize = NSSize(width: minHalfWidth, height: 480)
        let width = max(minHalfWidth, screen.width / 2 - gap)
        let frame = NSRect(x: screen.minX, y: screen.minY, width: width, height: screen.height)
        window.setFrame(frame, display: true, animate: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
