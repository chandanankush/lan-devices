import Foundation
import Combine

@MainActor
final class LDCDeviceRepository: ObservableObject {
    @Published private(set) var devices: [LDCDevice] = []
    @Published var isRefreshing = false
    @Published var showAddDeviceSheet = false
    @Published var sudoRequest: LDCSudoRequest?

    private let store = LDCDeviceStore.shared
    private let statusInterval: TimeInterval = 15
    private var cancellables: Set<AnyCancellable> = []
    private var statusTask: Task<Void, Never>?

    private let sshClient: LDCSSHClient
    private let expectClient = LDCExpectSSHClient()

    init(sshClient: LDCSSHClient? = nil) {
        #if canImport(NMSSH)
        self.sshClient = sshClient ?? LDCNMSSHClient()
        #else
        self.sshClient = sshClient ?? LDCProcessSSHClient()
        #endif
        reload()
        startStatusPolling()
    }

    func reload() {
        devices = store.fetchAll()
    }

    func add(_ device: LDCDevice) {
        store.upsert(device)
        reload()
    }

    func update(_ device: LDCDevice) {
        store.upsert(device)
        reload()
    }

    func remove(_ device: LDCDevice) {
        store.delete(id: device.id)
        reload()
    }

    func openInTerminal(_ device: LDCDevice) {
        LDCTerminalLauncher.openSSH(host: device.host, port: device.port, username: device.username, acceptNewHostKey: device.acceptNewHostKey)
    }

    func shutdown(_ device: LDCDevice) async {
        do {
            let client = (device.usePasswordAuth && (device.password?.isEmpty == false)) ? choosePasswordClient() : sshClient
            _ = try await client.shutdown(host: device.host, port: device.port, username: device.username, password: device.password, keyPath: device.sshKeyPath, acceptNewHostKey: device.acceptNewHostKey)
        } catch {
            print("[LDCDeviceRepository] shutdown error: \(error)")
            if needsSudoPassword(error: error) {
                sudoRequest = LDCSudoRequest(device: device, action: .shutdown)
            }
        }
    }

    func restart(_ device: LDCDevice) async {
        do {
            let client = (device.usePasswordAuth && (device.password?.isEmpty == false)) ? choosePasswordClient() : sshClient
            _ = try await client.restart(host: device.host, port: device.port, username: device.username, password: device.password, keyPath: device.sshKeyPath, acceptNewHostKey: device.acceptNewHostKey)
        } catch {
            print("[LDCDeviceRepository] restart error: \(error)")
            if needsSudoPassword(error: error) {
                sudoRequest = LDCSudoRequest(device: device, action: .restart)
            }
        }
    }

    private func choosePasswordClient() -> LDCSSHClient {
        #if canImport(NMSSH)
        return LDCNMSSHClient()
        #else
        return expectClient
        #endif
    }

    func refreshStatuses() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let snapshot = devices
        // Inherit MainActor for UI/SQLite updates; the asynchronous probe yields while waiting.
        Task { [weak self, snapshot] in
            guard let self else { return }
            defer { self.isRefreshing = false }
            for device in snapshot {
                let status = await LDCStatusChecker.check(host: device.host, port: device.port)
                self.store.updateStatus(id: device.id, status: status)
            }
            // Read the current records so additions/removals during a refresh remain visible.
            self.reload()
        }
    }

    private func startStatusPolling() {
        statusTask?.cancel()
        statusTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                self.refreshStatuses()
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
            print("[LDCDeviceRepository] sudo retry failed: \(error)")
        }
        sudoRequest = nil
    }

    private func needsSudoPassword(error: Error) -> Bool {
        let text = String(describing: error).lowercased()
        return text.contains("sudo") && (text.contains("password") || text.contains("a password is required"))
    }
}

enum LDCDeviceAction: String {
    case shutdown
    case restart
}

struct LDCSudoRequest: Identifiable {
    let id = UUID()
    let device: LDCDevice
    let action: LDCDeviceAction
}
