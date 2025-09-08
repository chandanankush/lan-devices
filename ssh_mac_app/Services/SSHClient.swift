import Foundation

protocol SSHClient {
    func run(host: String, port: Int, username: String, password: String?, keyPath: String?, acceptNewHostKey: Bool, command: String) async throws -> String
}

enum SSHClientError: Error, LocalizedError {
    case notAuthenticated
    case executionFailed(code: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "SSH authentication failed"
        case .executionFailed(let code, let output): return "SSH command failed (\(code)): \(output)"
        }
    }
}

// Default implementation using system ssh (key-based auth).
// Requires the host to be reachable and the user to have valid key-based auth or agent.
final class ProcessSSHClient: SSHClient {
    func run(host: String, port: Int, username: String, password: String?, keyPath: String?, acceptNewHostKey: Bool, command: String) async throws -> String {
        var args: [String] = ["-o", "BatchMode=yes", "-p", String(port)]
        if acceptNewHostKey {
            args += ["-o", "StrictHostKeyChecking=accept-new"]
        }
        if let keyPath = keyPath, !keyPath.isEmpty {
            args += ["-i", keyPath]
        }
        args.append("\(username)@\(host)")
        args.append(command)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        proc.arguments = args

        let outPipe = Pipe(); proc.standardOutput = outPipe
        let errPipe = Pipe(); proc.standardError = errPipe

        return try await withCheckedThrowingContinuation { cont in
            do {
                try proc.run()
            } catch {
                cont.resume(throwing: error)
                return
            }

            proc.terminationHandler = { p in
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData + errData, encoding: .utf8) ?? ""
                if p.terminationStatus == 0 {
                    cont.resume(returning: output)
                } else {
                    cont.resume(throwing: SSHClientError.executionFailed(code: p.terminationStatus, output: output))
                }
            }
        }
    }
}

#if canImport(NMSSH)
import NMSSH

// Optional NMSSH-based implementation that supports password auth.
final class NMSSHClient: SSHClient {
    func run(host: String, port: Int, username: String, password: String?, keyPath: String?, acceptNewHostKey: Bool, command: String) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let session = NMSSHSession(host: host, andUsername: username)
            session?.port = UInt16(port)
            session?.connect()

            guard session?.isConnected == true else {
                cont.resume(throwing: SSHClientError.notAuthenticated)
                return
            }

            var authed = false
            if let pw = password, !pw.isEmpty {
                authed = session?.authenticate(byPassword: pw) == true
            } else if let keyPath = keyPath, !keyPath.isEmpty {
                authed = session?.authenticateBy(inMemoryPublicKey: nil, privateKey: keyPath, andPassword: password) == true
            } else {
                authed = session?.authenticateByPublicKey(nil, privateKey: nil, andPassword: nil) == true
            }

            guard authed, session?.isAuthorized == true else {
                session?.disconnect()
                cont.resume(throwing: SSHClientError.notAuthenticated)
                return
            }

            let channel = NMSSHChannel(session: session)
            var error: NSError?
            let output = channel?.execute(command, error: &error, timeout: 10) ?? ""
            session?.disconnect()
            if let error = error { cont.resume(throwing: error) } else { cont.resume(returning: output) }
        }
    }
}
#endif

// Convenience helpers for shutdown/restart
extension SSHClient {
    func shutdown(host: String, port: Int, username: String, password: String?, keyPath: String?, acceptNewHostKey: Bool) async throws -> String {
        let cmd = buildSudoCommand(base: "shutdown -h now", password: password)
        return try await run(host: host, port: port, username: username, password: password, keyPath: keyPath, acceptNewHostKey: acceptNewHostKey, command: cmd)
    }

    func restart(host: String, port: Int, username: String, password: String?, keyPath: String?, acceptNewHostKey: Bool) async throws -> String {
        let cmd = buildSudoCommand(base: "shutdown -r now", password: password)
        return try await run(host: host, port: port, username: username, password: password, keyPath: keyPath, acceptNewHostKey: acceptNewHostKey, command: cmd)
    }
}

fileprivate func shellSingleQuoted(_ s: String) -> String {
    return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

fileprivate func buildSudoCommand(base: String, password: String?) -> String {
    if let pw = password, !pw.isEmpty {
        return "printf %s " + shellSingleQuoted(pw) + " | sudo -S -p '' " + base
    } else {
        return "sudo -n " + base
    }
}
