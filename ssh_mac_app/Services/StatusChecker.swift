import Foundation
import Network

enum StatusCheckError: Error {
    case timedOut
}

final class StatusChecker {
    static func check(host: String, port: Int = 22, timeout: TimeInterval = 2.5) async -> DeviceStatus {
        await withCheckedContinuation { cont in
            let params = NWParameters.tcp
            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
                cont.resume(returning: .unreachable)
                return
            }
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
            let conn = NWConnection(to: endpoint, using: params)

            var completed = false
            let queue = DispatchQueue.global(qos: .utility)
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !completed { completed = true; conn.cancel(); cont.resume(returning: .reachable) }
                case .failed(_):
                    if !completed { completed = true; conn.cancel(); cont.resume(returning: .unreachable) }
                case .cancelled:
                    if !completed { completed = true; cont.resume(returning: .unreachable) }
                default:
                    break
                }
            }

            conn.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                if !completed {
                    completed = true
                    conn.cancel()
                    cont.resume(returning: .unreachable)
                }
            }
        }
    }
}
