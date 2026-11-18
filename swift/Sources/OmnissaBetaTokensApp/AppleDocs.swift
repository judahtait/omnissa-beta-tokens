import AppKit
import Foundation

/// Canonical Apple Developer Documentation links for AppleSeed / Software Update Beta.
/// Used by Help menu and the UEM guidance sheet.
enum AppleDocs {
    static let enrollingDevice = URL(string:
        "https://developer.apple.com/documentation/devicemanagement/enrolling-a-device-in-a-beta-program")!
    static let getBetaTokens = URL(string:
        "https://developer.apple.com/documentation/devicemanagement/get-beta-enrollment-tokens")!
    static let declarativeSoftwareUpdates = URL(string:
        "https://developer.apple.com/documentation/devicemanagement/deploying-software-updates-using-declarative-management")!
    static let softwareUpdate = URL(string:
        "https://developer.apple.com/documentation/devicemanagement/softwareupdate")!
    static let appleSeedForIT = URL(string: "https://beta.apple.com/for-it")!
    static let wwdc24DeviceManagement = URL(string:
        "https://developer.apple.com/videos/play/wwdc2024/10143/")!

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
