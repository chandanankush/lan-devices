import Foundation
import CryptoKit

struct HostKey: Identifiable, Equatable {
    let id = UUID()
    let type: String
    let keyDataBase64: String
    let fingerprint: String // OpenSSH-style: SHA256:<base64-no-padding>
}

enum HostKeyError: Error, LocalizedError {
    case noKeys
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .noKeys: return "No host keys discovered."
        case .failed(let msg): return msg
        }
    }
}

enum HostKeyService {
    static func scan(host: String, port: Int) async throws -> [HostKey] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keyscan")
        proc.arguments = ["-T", "5", "-p", String(port), "-t", "rsa,ecdsa,ed25519", host]

        let out = Pipe(); proc.standardOutput = out
        let err = Pipe(); proc.standardError = err

        return try await withCheckedThrowingContinuation { cont in
            do { try proc.run() } catch { cont.resume(throwing: error); return }
            proc.terminationHandler = { p in
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                guard p.terminationStatus == 0 || !data.isEmpty else {
                    let msg = String(data: errData, encoding: .utf8) ?? "ssh-keyscan failed"
                    cont.resume(throwing: HostKeyError.failed(msg))
                    return
                }
                let text = String(decoding: data, as: UTF8.self)
                let keys = parse(text: text)
                if keys.isEmpty {
                    cont.resume(throwing: HostKeyError.noKeys)
                } else {
                    cont.resume(returning: keys)
                }
            }
        }
    }

    private static func parse(text: String) -> [HostKey] {
        var result: [HostKey] = []
        for line in text.split(separator: "\n") {
            // Expected: "host keytype base64 [comment]"
            let parts = line.split(separator: " ")
            guard parts.count >= 3 else { continue }
            let type = String(parts[1])
            let base64 = String(parts[2])
            guard let data = Data(base64Encoded: base64) else { continue }
            let digest = SHA256.hash(data: data)
            let fpRaw = Data(digest).base64EncodedString()
            let fpNoPad = fpRaw.replacingOccurrences(of: "=", with: "")
            let fp = "SHA256:\(fpNoPad)"
            result.append(HostKey(type: type, keyDataBase64: base64, fingerprint: fp))
        }
        return result
    }
}

