import Foundation

struct DiscoveredDevice: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var host: String
    var port: Int
}

final class DiscoveryService: NSObject, ObservableObject {
    @Published private(set) var devices: [DiscoveredDevice] = []
    @Published private(set) var isScanning: Bool = false

    private var browser: NetServiceBrowser?
    private var services: [NetService] = []
    private var scanTask: Task<Void, Never>?

    func start() {
        stop()
        let browser = NetServiceBrowser()
        self.browser = browser
        browser.delegate = self
        browser.searchForServices(ofType: "_ssh._tcp.", inDomain: "local.")
        // Kick off a subnet scan for SSH port after Bonjour starts
        scanSubnetForSSH()
    }

    func stop() {
        browser?.stop()
        browser = nil
        services.removeAll()
        scanTask?.cancel()
        isScanning = false
    }

    func rescan() {
        scanSubnetForSSH(force: true)
    }

    private func scanSubnetForSSH(force: Bool = false) {
        if isScanning && !force { return }
        isScanning = true
        let scanner = SubnetScanner()
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            let results = await scanner.scanSSH()
            await MainActor.run {
                guard let self else { return }
                // Merge results with existing devices, de-duping by host:port
                for r in results {
                    if self.devices.contains(where: { $0.host == r.host && $0.port == r.port }) == false {
                        self.devices.append(r)
                    }
                }
                self.isScanning = false
            }
        }
    }
}

extension DiscoveryService: NetServiceBrowserDelegate, NetServiceDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        if services.contains(where: { $0 === service }) == false {
            services.append(service)
        }
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll(where: { $0 === service })
        if let hostName = service.hostName {
            if let idx = devices.firstIndex(where: { $0.host == hostName && $0.port == service.port }) {
                devices.remove(at: idx)
            }
        }
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let hostName = sender.hostName else { return }
        let item = DiscoveredDevice(name: sender.name, host: hostName, port: sender.port)
        if devices.contains(where: { $0.host == item.host && $0.port == item.port }) == false {
            devices.append(item)
        }
    }
}
