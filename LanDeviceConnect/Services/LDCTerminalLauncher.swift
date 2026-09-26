import Foundation
import AppKit

enum LDCTerminalLauncher {
    static func openSSH(host: String, port: Int = 22, username: String, acceptNewHostKey: Bool = true) {
        var command = "ssh -p \(port) \(username)@\(host)"
        if acceptNewHostKey {
            command = "ssh -o StrictHostKeyChecking=accept-new -p \(port) \(username)@\(host)"
        }
        let script = """
        tell application "Terminal"
            activate
            do script "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var err: NSDictionary?
            appleScript.executeAndReturnError(&err)
            if let err = err { print("[LDCTerminalLauncher] AppleScript error: \(err)") }
        } else {
            // Fallback: open Terminal app (without running the command)
            guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
                print("[LDCTerminalLauncher] Terminal application was not found")
                return
            }
            NSWorkspace.shared.openApplication(at: terminalURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error { print("[LDCTerminalLauncher] Failed to open Terminal: \(error)") }
            }
        }
    }
}
