import AppKit
import ApplicationServices

/// Side-by-side layout: this app on the left half, the default browser on the right.
/// Used by `AppModel.openAppleBusiness()`.
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

    /// Open `url` in the default browser, then pin that browser’s front window to the right half.
    static func openURLAndTileBrowserRight(_ url: URL) {
        let browserBundle = defaultBrowserBundleID(for: url)
        if let browserURL = browserAppURL(bundleID: browserBundle) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration: config) { _, _ in
                scheduleBrowserTileRetries(preferredBundleID: browserBundle)
            }
        } else {
            NSWorkspace.shared.open(url)
            scheduleBrowserTileRetries(preferredBundleID: browserBundle)
        }
    }

    private static func scheduleBrowserTileRetries(preferredBundleID: String?) {
        let delays: [TimeInterval] = [0.6, 1.2, 2.0, 3.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                _ = tileBrowserRightHalf(preferredBundleID: preferredBundleID)
            }
        }
    }

    @discardableResult
    private static func tileBrowserRightHalf(preferredBundleID: String?) -> Bool {
        guard let screen = NSScreen.main?.visibleFrame else { return false }
        let leftWidth = max(minHalfWidth, screen.width / 2 - gap)
        let frame = CGRect(
            x: screen.minX + leftWidth + gap,
            y: screen.minY,
            width: screen.maxX - (screen.minX + leftWidth + gap),
            height: screen.height
        )

        if let pid = browserPID(preferredBundleID: preferredBundleID),
           setFrontWindowFrame(pid: pid, frame: frame) {
            if let app = NSRunningApplication(processIdentifier: pid) {
                app.activate(options: [.activateIgnoringOtherApps])
            }
            tileAppLeft()
            return true
        }

        if tileBrowserViaAppleScript(frame: frame, preferredBundleID: preferredBundleID) {
            tileAppLeft()
            return true
        }
        return false
    }

    private static func defaultBrowserBundleID(for url: URL) -> String? {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) else { return nil }
        return Bundle(url: appURL)?.bundleIdentifier
    }

    private static func browserAppURL(bundleID: String?) -> URL? {
        guard let bundleID else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    private static func browserPID(preferredBundleID: String?) -> pid_t? {
        let running = NSWorkspace.shared.runningApplications
        if let preferredBundleID,
           let match = running.first(where: { $0.bundleIdentifier == preferredBundleID && !$0.isTerminated }) {
            return match.processIdentifier
        }
        let known: Set<String> = [
            "com.apple.Safari",
            "com.google.Chrome",
            "com.microsoft.edgemac",
            "company.thebrowser.Browser",
            "com.brave.Browser",
            "org.mozilla.firefox",
            "com.apple.SafariTechnologyPreview",
        ]
        return running.first { app in
            guard let id = app.bundleIdentifier else { return false }
            return known.contains(id) && !app.isTerminated
        }?.processIdentifier
    }

    private static func setFrontWindowFrame(pid: pid_t, frame: CGRect) -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        let appRef = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement],
              let window = windows.first
        else { return false }

        var position = CGPoint(x: frame.minX, y: frame.minY)
        var size = CGSize(width: frame.width, height: frame.height)
        guard let posVal = AXValueCreate(.cgPoint, &position),
              let sizeVal = AXValueCreate(.cgSize, &size)
        else { return false }

        let posStatus = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        let sizeStatus = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
        return posStatus == .success && sizeStatus == .success
    }

    private static func tileBrowserViaAppleScript(frame: CGRect, preferredBundleID: String?) -> Bool {
        let left = Int(frame.minX.rounded())
        let bottom = Int(frame.minY.rounded())
        let right = Int(frame.maxX.rounded())
        let top = Int(frame.maxY.rounded())
        let apps = appleScriptAppNames(preferredBundleID: preferredBundleID)
        let tries = apps.map { name in
            """
            try
              tell application "\(name)"
                if (count of windows) > 0 then
                  set bounds of front window to {\(left), \(bottom), \(right), \(top)}
                  activate
                  return "ok"
                end if
              end tell
            end try
            """
        }.joined(separator: "\n")
        let script = """
        on run
          \(tries)
          return "miss"
        end run
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return false }
        let result = appleScript.executeAndReturnError(&error)
        return result.stringValue == "ok"
    }

    private static func appleScriptAppNames(preferredBundleID: String?) -> [String] {
        let map: [String: String] = [
            "com.apple.Safari": "Safari",
            "com.google.Chrome": "Google Chrome",
            "com.microsoft.edgemac": "Microsoft Edge",
            "company.thebrowser.Browser": "Arc",
            "com.brave.Browser": "Brave Browser",
            "org.mozilla.firefox": "Firefox",
            "com.apple.SafariTechnologyPreview": "Safari Technology Preview",
        ]
        var names = ["Safari", "Google Chrome", "Microsoft Edge", "Arc", "Brave Browser", "Firefox"]
        if let preferredBundleID, let preferred = map[preferredBundleID] {
            names.removeAll { $0 == preferred }
            names.insert(preferred, at: 0)
        }
        return names
    }
}
