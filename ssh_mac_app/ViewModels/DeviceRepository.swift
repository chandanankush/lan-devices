import Foundation
import Combine

@MainActor
final class DeviceRepository: ObservableObject {
    @Published private(set) var devices: [Device] = []
    @Published var isRefreshing = false
    @Published var showAddDeviceSheet = false
    @Published var sudoRequest: SudoRequest?

    private let store = DeviceStore.shared
    private let statusInterval: TimeInterval = 15
    private var cancellables: Set<AnyCancellable> = []
    private var statusTask: Task<Void, Never>?

    private let sshClient: SSHClient
    private let expectClient = ExpectSSHClient()

    init(sshClient: SSHClient? = nil) {
        #if canImport(NMSSH)
        self.sshClient = sshClient ?? NMSSHClient()
        #else
        self.sshClient = sshClient ?? ProcessSSHClient()
        #endif
        reload()
        startStatusPolling()
    }

    func reload() {
        devices = store.fetchAll()
    }

    func add(_ device: Device) {
        store.upsert(device)
        reload()
    }

    func update(_ device: Device) {
        store.upsert(device)
        reload()
    }

    func remove(_ device: Device) {
        store.delete(id: device.id)
        reload()
    }

    func openInTerminal(_ device: Device) {
        TerminalLauncher.openSSH(host: device.host, port: device.port, username: device.username, acceptNewHostKey: device.acceptNewHostKey)
    }

    func shutdown(_ device: Device) async {
        do {
            let client = (device.usePasswordAuth && (device.password?.isEmpty == false)) ? choosePasswordClient() : sshClient
            _ = try await client.shutdown(host: device.host, port: device.port, username: device.username, password: device.password, keyPath: device.sshKeyPath, acceptNewHostKey: device.acceptNewHostKey)
        } catch {
            print("[DeviceRepository] shutdown error: \(error)")
            if needsSudoPassword(error: error) {
                sudoRequest = SudoRequest(device: device, action: .shutdown)
            }
        }
    }

    func restart(_ device: Device) async {
        do {
            let client = (device.usePasswordAuth && (device.password?.isEmpty == false)) ? choosePasswordClient() : sshClient
            _ = try await client.restart(host: device.host, port: device.port, username: device.username, password: device.password, keyPath: device.sshKeyPath, acceptNewHostKey: device.acceptNewHostKey)
        } catch {
            print("[DeviceRepository] restart error: \(error)")
            if needsSudoPassword(error: error) {
                sudoRequest = SudoRequest(device: device, action: .restart)
            }
        }
    }

    private func choosePasswordClient() -> SSHClient {
        #if canImport(NMSSH)
        return NMSSHClient()
        #else
        return expectClient
        #endif
    }

    func refreshStatuses() {
        guard !isRefreshing else { return }
        isRefreshing = true
        // Snapshot devices on MainActor to avoid cross-actor access in detached task
        let snapshot = self.devices
        Task.detached { [weak self, snapshot] in
            guard let self = self else { return }
            var updated: [Device] = []
            for var d in snapshot {
                let status = await StatusChecker.check(host: d.host, port: d.port)
                d.status = status
                await MainActor.run {
                    self.store.updateStatus(id: d.id, status: status)
                }
                updated.append(d)
            }
            await MainActor.run {
                self.devices = updated
                self.isRefreshing = false
            }
        }
    }

    private func startStatusPolling() {
        statusTask?.cancel()
        statusTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                await MainActor.run { self.refreshStatuses() }
                try? await Task.sleep(nanoseconds: UInt64(statusInterval * 1_000_000_000))
            }
        }
    }

    // MARK: - Sudo prompt
    func submitSudoPassword(_ password: String, remember: Bool) async {
        guard let req = sudoRequest else { return }
        var device = req.device
        if remember {
            device.password = password
            // Do not force SSH password auth; keep key-based if set.
            store.upsert(device)
            reload()
        }
        do {
            switch req.action {
            case .shutdown:
                _ = try await sshClient.shutdown(host: device.host, port: device.port, username: device.username, password: password, keyPath: device.sshKeyPath, acceptNewHostKey: device.acceptNewHostKey)
            case .restart:
                _ = try await sshClient.restart(host: device.host, port: device.port, username: device.username, password: password, keyPath: device.sshKeyPath, acceptNewHostKey: device.acceptNewHostKey)
            }
        } catch {
            print("[DeviceRepository] sudo retry failed: \(error)")
        }
        sudoRequest = nil
    }

    private func needsSudoPassword(error: Error) -> Bool {
        let text = String(describing: error).lowercased()
        return text.contains("sudo") && (text.contains("password") || text.contains("a password is required"))
    }
}

enum DeviceAction: String {
    case shutdown
    case restart
}

struct SudoRequest: Identifiable {
    let id = UUID()
    let device: Device
    let action: DeviceAction
}
