import Foundation
import Network

enum LDCStatusCheckError: Error {
    case timedOut
}

final class LDCStatusChecker {
    static func check(host: String, port: Int = 22, timeout: TimeInterval = 2.5) async -> LDCDeviceStatus {
        guard let rawPort = UInt16(exactly: port), rawPort > 0,
              let nwPort = NWEndpoint.Port(rawValue: rawPort) else {
            return .unreachable
        }
        return await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
            let connection = NWConnection(to: endpoint, using: .tcp)
            let completion = LDCStatusCheckCompletion(continuation: continuation)
            let queue = DispatchQueue.global(qos: .utility)

            connection.stateUpdateHandler = { state in
                let status: LDCDeviceStatus
                switch state {
                case .ready: status = .reachable
                case .failed, .cancelled: status = .unreachable
                default: return
                }
                Task { await completion.finish(status: status, connection: connection) }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                Task { await completion.finish(status: .unreachable, connection: connection) }
            }
        }
    }
}

/// Serializes ready, failure, cancellation, and timeout so the continuation resumes once.
private actor LDCStatusCheckCompletion {
    private var continuation: CheckedContinuation<LDCDeviceStatus, Never>?

    init(continuation: CheckedContinuation<LDCDeviceStatus, Never>) {
        self.continuation = continuation
    }

    func finish(status: LDCDeviceStatus, connection: NWConnection) {
        guard let continuation else { return }
        self.continuation = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
        continuation.resume(returning: status)
    }
}
