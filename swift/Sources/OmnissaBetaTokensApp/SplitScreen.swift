import AppKit
import ApplicationServices

/// Side-by-side layout: this app on the left half, the default browser on the right.
/// Used by `AppModel.openAppleBusiness()`.
///
/// Only targets the **default** browser that is actually installed. Never
/// `tell application` for Edge/Firefox/etc. that are missing — macOS would
/// open "Where is …?" pickers (and our old retry loop stacked several of them).
enum SplitScreen {
    private static let gap: CGFloat = 8
    private static let minHalfWidth: CGFloat = 520

    private static let browserNames: [String: String] = [
        "com.apple.Safari": "Safari",
        "com.google.Chrome": "Google Chrome",
        "com.microsoft.edgemac": "Microsoft Edge",
        "company.thebrowser.Browser": "Arc",
        "com.brave.Browser": "Brave Browser",
        "org.mozilla.firefox": "Firefox",
        "com.apple.SafariTechnologyPreview": "Safari Technology Preview",
    ]

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
        let browser = resolvedBrowser(for: url)
        if let appURL = browser.appURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config) { _, _ in
                scheduleBrowserTileRetries(browser: browser)
            }
        } else {
            NSWorkspace.shared.open(url)
            scheduleBrowserTileRetries(browser: browser)
        }
    }

    private struct BrowserTarget {
        let bundleID: String?
        let appURL: URL?
        var appleScriptName: String? {
            guard let bundleID else { return nil }
            return browserNames[bundleID]
        }
    }

    private static func resolvedBrowser(for url: URL) -> BrowserTarget {
        let appURL = NSWorkspace.shared.urlForApplication(toOpen: url)
        let bundleID = appURL.flatMap { Bundle(url: $0)?.bundleIdentifier }
        // Only keep the ID if that app is really on disk (avoids "Where is …?" dialogs).
        if let bundleID,
           NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil {
            return BrowserTarget(bundleID: bundleID, appURL: appURL)
        }
        return BrowserTarget(bundleID: nil, appURL: appURL)
    }

    private static func scheduleBrowserTileRetries(browser: BrowserTarget) {
        let delays: [TimeInterval] = [0.8, 1.6, 2.8]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if tileBrowserRightHalf(browser: browser) {
                    // Later scheduled retries become no-ops once the window is already placed;
                    // they only re-assert the same frame on the same installed browser.
                }
            }
        }
    }

    @discardableResult
    private static func tileBrowserRightHalf(browser: BrowserTarget) -> Bool {
        guard let screen = NSScreen.main?.visibleFrame else { return false }
        let leftWidth = max(minHalfWidth, screen.width / 2 - gap)
        let frame = CGRect(
            x: screen.minX + leftWidth + gap,
            y: screen.minY,
            width: screen.maxX - (screen.minX + leftWidth + gap),
            height: screen.height
        )

        if let pid = browserPID(bundleID: browser.bundleID),
           setFrontWindowFrame(pid: pid, frame: frame) {
            NSRunningApplication(processIdentifier: pid)?
                .activate(options: [.activateIgnoringOtherApps])
            tileAppLeft()
            return true
        }

        // AppleScript only for the one installed default browser — never probe others.
        if let name = browser.appleScriptName,
           tileBrowserViaAppleScript(appName: name, frame: frame) {
            tileAppLeft()
            return true
        }
        return false
    }

    private static func browserPID(bundleID: String?) -> pid_t? {
        guard let bundleID else { return nil }
        return NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleID && !$0.isTerminated }?
            .processIdentifier
    }

    private static func setFrontWindowFrame(pid: pid_t, frame: CGRect) -> Bool {
        // Prompt at most when not yet trusted; avoid re-prompt storms on retries.
        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
        }
        guard AXIsProcessTrusted() else { return false }

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

    private static func tileBrowserViaAppleScript(appName: String, frame: CGRect) -> Bool {
        let left = Int(frame.minX.rounded())
        let bottom = Int(frame.minY.rounded())
        let right = Int(frame.maxX.rounded())
        let top = Int(frame.maxY.rounded())
        // `tell application id` still resolves missing apps; we only pass names we verified exist.
        let script = """
        on run
          tell application "\(appName)"
            if (count of windows) = 0 then return "miss"
            set bounds of front window to {\(left), \(bottom), \(right), \(top)}
            activate
          end tell
          return "ok"
        end run
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return false }
        let result = appleScript.executeAndReturnError(&error)
        return error == nil && result.stringValue == "ok"
    }
}
