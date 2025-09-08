import Foundation

final class ExpectSSHClient: SSHClient {
    func run(host: String, port: Int, username: String, password: String?, keyPath: String?, acceptNewHostKey: Bool, command: String) async throws -> String {
        guard let password, !password.isEmpty else {
            // No password; delegate to ProcessSSHClient
            return try await ProcessSSHClient().run(host: host, port: port, username: username, password: nil, keyPath: keyPath, acceptNewHostKey: acceptNewHostKey, command: command)
        }

        // Build ssh command string
        var sshParts: [String] = ["ssh", "-tt"]
        if acceptNewHostKey { sshParts += ["-o", "StrictHostKeyChecking=accept-new"] }
        sshParts += ["-p", String(port)]
        if let keyPath, !keyPath.isEmpty { sshParts += ["-i", keyPath] }
        sshParts.append("\(username)@\(host)")
        // Wrap the remote command with sh -lc to get consistent shell behavior
        let remote = "sh -lc \"\(command.replacingOccurrences(of: "\\\"", with: "\\\\\\\""))\""
        sshParts.append(remote)
        let sshCmd = sshParts.map { escapeExpectArg($0) }.joined(separator: " ")

        let script = """
        set timeout 30
        log_user 1
        spawn -noecho \(sshCmd)
        expect {
          -re {(?i)password:} { send -- "\(escapeForExpect(password))\r"; exp_continue }
          -re {Are you sure you want to continue connecting.*} { send -- "yes\r"; exp_continue }
          -re {Permission denied} { exit 255 }
          eof
        }
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/expect")
        let inPipe = Pipe(); proc.standardInput = inPipe
        let outPipe = Pipe(); proc.standardOutput = outPipe
        let errPipe = Pipe(); proc.standardError = errPipe

        return try await withCheckedThrowingContinuation { cont in
            do { try proc.run() } catch { cont.resume(throwing: error); return }
            // send script on stdin
            inPipe.fileHandleForWriting.write(script.data(using: .utf8)!)
            inPipe.fileHandleForWriting.closeFile()
            proc.terminationHandler = { p in
                let out = outPipe.fileHandleForReading.readDataToEndOfFile()
                let err = errPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: out + err, encoding: .utf8) ?? ""
                if p.terminationStatus == 0 {
                    cont.resume(returning: output)
                } else {
                    cont.resume(throwing: SSHClientError.executionFailed(code: p.terminationStatus, output: output))
                }
            }
        }
    }
}

private func escapeForExpect(_ s: String) -> String {
    // Escape backslashes and quotes for expect string literal
    var r = s.replacingOccurrences(of: "\\", with: "\\\\")
    r = r.replacingOccurrences(of: "\"", with: "\\\"")
    return r
}

private func escapeExpectArg(_ s: String) -> String {
    // Quote args for safe inclusion in expect's spawn line
    if s.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "'\"$`\\"))) != nil {
        return "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
    return s
}
