import Foundation
import AppKit

enum TerminalLauncher {
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
            if let err = err { print("[TerminalLauncher] AppleScript error: \(err)") }
        } else {
            // Fallback: open Terminal app (without running the command)
            NSWorkspace.shared.launchApplication("Terminal")
        }
    }
}
