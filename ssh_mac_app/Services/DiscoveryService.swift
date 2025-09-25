import Foundation
import Darwin

enum DiscoverySource: String, Codable, Hashable {
    case bonjour
    case subnet
}

struct DiscoveredDevice: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var host: String
    var port: Int
    var ip: String?
    var source: DiscoverySource
    var latencyMs: Int?
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

    private static func firstIPAddress(from addresses: [Data]?) -> String? {
        guard let addresses, !addresses.isEmpty else { return nil }
        for data in addresses {
            let result: String? = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                guard let base = ptr.baseAddress else { return nil }
                let sa = base.assumingMemoryBound(to: sockaddr.self).pointee
                switch Int32(sa.sa_family) {
                case AF_INET:
                    let sin = base.assumingMemoryBound(to: sockaddr_in.self).pointee
                    var addr = sin.sin_addr
                    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                    return String(cString: buffer)
                case AF_INET6:
                    let sin6 = base.assumingMemoryBound(to: sockaddr_in6.self).pointee
                    var addr6 = sin6.sin6_addr
                    var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    inet_ntop(AF_INET6, &addr6, &buffer, socklen_t(INET6_ADDRSTRLEN))
                    return String(cString: buffer)
                default:
                    return nil
                }
            }
            if let ip = result { return ip }
        }
        return nil
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
        let ip = Self.firstIPAddress(from: sender.addresses)
        let item = DiscoveredDevice(name: sender.name, host: hostName, port: sender.port, ip: ip, source: .bonjour, latencyMs: nil)
        if devices.contains(where: { $0.host == item.host && $0.port == item.port }) == false {
            devices.append(item)
        }
    }
}
