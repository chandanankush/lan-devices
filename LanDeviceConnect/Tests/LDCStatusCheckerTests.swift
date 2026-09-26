import Foundation
import Network

private enum LDCTestFailure: Error {
    case assertion(String)
}

private actor LDCTestServerConnections {
    private var connections: [NWConnection] = []

    func accept(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: DispatchQueue(label: "LDCStatusCheckerTests.server"))
    }

    func stop() {
        for connection in connections { connection.cancel() }
        connections.removeAll()
    }
}

@main
struct LDCStatusCheckerTests {
    static func main() async throws {
        let connections = LDCTestServerConnections()
        let listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { connection in
            Task { await connections.accept(connection) }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default: break
                }
            }
            listener.start(queue: DispatchQueue(label: "LDCStatusCheckerTests.listener"))
        }
        let port = Int(listener.port!.rawValue)
        let reachable = await LDCStatusChecker.check(host: "127.0.0.1", port: port, timeout: 2)
        try require(reachable == .reachable, "An accepting local TCP server must be reachable")
        print("PASS: reachable local server")

        // Ready, cancellation, and the timeout can arrive together. Every call must finish once.
        let results = await withTaskGroup(of: LDCDeviceStatus.self, returning: [LDCDeviceStatus].self) { group in
            for index in 0..<200 {
                group.addTask {
                    await LDCStatusChecker.check(host: "127.0.0.1", port: port, timeout: index.isMultiple(of: 2) ? 0 : 0.01)
                }
            }
            var results: [LDCDeviceStatus] = []
            for await result in group { results.append(result) }
            return results
        }
        try require(results.count == 200, "All racing checks must return")
        try require(results.allSatisfy { $0 == .reachable || $0 == .unreachable }, "Checks must return a final status")
        print("PASS: 200 simultaneous ready/timeout races")

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            listener.stateUpdateHandler = { state in
                if case .cancelled = state {
                    listener.stateUpdateHandler = nil
                    continuation.resume()
                }
            }
            listener.cancel()
        }
        await connections.stop()
        let refused = await LDCStatusChecker.check(host: "127.0.0.1", port: port, timeout: 2)
        try require(refused == .unreachable, "A closed local port must be unreachable")
        print("PASS: refused local connection")

        for invalidPort in [-1, 0, 65536] {
            let status = await LDCStatusChecker.check(host: "127.0.0.1", port: invalidPort)
            try require(status == .unreachable, "Invalid port \(invalidPort) must return unreachable without trapping")
        }
        print("PASS: invalid port boundaries")
        try await refreshPreservesCurrentDevices()

    }

    @MainActor
    private static func refreshPreservesCurrentDevices() async throws {
        let original = LDCDevice(name: "Original", host: "127.0.0.1", port: 0, username: "test")
        LDCDeviceStore.shared.upsert(original)
        let repository = LDCDeviceRepository()
        repository.refreshStatuses()
        let added = LDCDevice(name: "Added during refresh", host: "127.0.0.1", port: 0, username: "test")
        repository.add(added)
        repository.remove(original)
        let deadline = Date().addingTimeInterval(3)
        while repository.isRefreshing && Date() < deadline { await Task.yield() }
        try require(!repository.isRefreshing, "Status refresh must finish")
        try require(repository.devices.contains { $0.id == added.id }, "Refresh must preserve devices added while probes are running")
        try require(!repository.devices.contains { $0.id == original.id }, "Refresh must not restore a removed device from an old snapshot")
        print("PASS: refresh preserves additions and removals")
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw LDCTestFailure.assertion(message) }
    }
}
