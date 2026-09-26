import Foundation
import Combine
import Darwin

enum LDCDiscoverySource: String, Codable, Hashable {
    case bonjour
    case subnet
}

struct LDCDiscoveredDevice: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var host: String
    var port: Int
    var ip: String?
    var source: LDCDiscoverySource
    var latencyMs: Int?
    var manufacturer: String? = nil
    var model: String? = nil

    static func normalizedHost(_ host: String) -> String {
        host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
    }

    var endpoints: Set<String> {
        Set([host, ip].compactMap { $0 }.map(Self.normalizedHost))
    }

    var hasName: Bool {
        guard !name.isEmpty else { return false }
        var ipv4 = in_addr()
        var ipv6 = in6_addr()
        return inet_pton(AF_INET, name, &ipv4) != 1 && inet_pton(AF_INET6, name, &ipv6) != 1
    }
}

final class LDCDiscoveryService: NSObject, ObservableObject {
    @Published private(set) var devices: [LDCDiscoveredDevice] = []
    @Published private(set) var isScanning: Bool = false

    private var browsers: [NetServiceBrowser] = []
    private var identities: [String: LDCDiscoveredDevice] = [:]
    private var identityTasks: [String: Task<Void, Never>] = [:]
    private var services: [NetService] = []
    private var scanTask: Task<Void, Never>?

    func start() {
        stop()
        devices.removeAll()
        identities.removeAll()
        // Other advertisements provide names/metadata; only SSH endpoints become rows.
        for type in ["_ssh._tcp.", "_device-info._tcp.", "_workstation._tcp.", "_smb._tcp."] {
            let browser = NetServiceBrowser()
            browsers.append(browser)
            browser.delegate = self
            browser.searchForServices(ofType: type, inDomain: "local.")
        }
        // Kick off a subnet scan for SSH port after Bonjour starts
        scanSubnetForSSH()
    }

    func stop() {
        for browser in browsers {
            browser.delegate = nil
            browser.stop()
        }
        browsers.removeAll()
        for service in services {
            service.delegate = nil
            service.stopMonitoring()
            service.stop()
        }
        services.removeAll()
        for task in identityTasks.values { task.cancel() }
        identityTasks.removeAll()
        scanTask?.cancel()
        isScanning = false
    }

    func rescan() {
        for task in identityTasks.values { task.cancel() }
        identityTasks.removeAll()
        scanSubnetForSSH(force: true)
    }

    private func scanSubnetForSSH(force: Bool = false) {
        if isScanning && !force { return }
        isScanning = true
        let scanner = LDCSubnetScanner()
        scanTask?.cancel()
        scanTask = Task { @MainActor [weak self] in
            let results = await scanner.scanSSH()
            guard !Task.isCancelled, let self else { return }
            // Merge Bonjour and subnet results by hostname/IP and SSH port.
            for result in results {
                self.merge(result)
                self.resolveIdentity(for: result)
            }
            self.isScanning = false
        }
    }

    // Preserve the row identity while replacing IP-only results with resolved names.
    func merge(_ result: LDCDiscoveredDevice) {
        var incoming = result
        for identity in identities.values where !identity.endpoints.isDisjoint(with: incoming.endpoints) {
            enrich(&incoming, with: identity)
        }
        guard let index = devices.firstIndex(where: {
            $0.port == incoming.port && !$0.endpoints.isDisjoint(with: incoming.endpoints)
        }) else {
            devices.append(incoming)
            return
        }
        var existing = devices[index]
        if incoming.hasName && (incoming.source == .bonjour || !existing.hasName) { existing.name = incoming.name }
        if incoming.ip != nil { existing.ip = incoming.ip }
        if incoming.source == .bonjour {
            existing.host = incoming.host
            existing.source = .bonjour
        }
        existing.latencyMs = incoming.latencyMs ?? existing.latencyMs
        existing.manufacturer = incoming.manufacturer ?? existing.manufacturer
        existing.model = incoming.model ?? existing.model
        devices[index] = existing
    }

    private func resolveIdentity(for device: LDCDiscoveredDevice) {
        guard let ip = device.ip, identityTasks[ip] == nil else { return }
        identityTasks[ip] = Task { @MainActor [weak self] in
            let hostname = await LDCReverseDNSResolver().lookup(address: ip)
            guard !Task.isCancelled, let self else { return }
            if let hostname {
                var named = device
                named.name = hostname
                // Keep the scanned IP as the connection target when only PTR data is known.
                self.merge(named)
            }
        }
    }

    private func enrich(_ device: inout LDCDiscoveredDevice, with identity: LDCDiscoveredDevice) {
        if identity.hasName && !device.hasName { device.name = identity.name }
        device.manufacturer = identity.manufacturer ?? device.manufacturer
        device.model = identity.model ?? device.model
    }

    private func updateIdentity(from service: NetService, txtRecord: Data? = nil) {
        guard let host = service.hostName else { return }
        var identity = LDCDiscoveredDevice(name: service.name, host: host, port: 0,
            ip: Self.firstIPAddress(from: service.addresses), source: .bonjour, latencyMs: nil)
        // Workstation names often append a MAC address in square brackets.
        if service.type == "_workstation._tcp.", let suffix = identity.name.range(of: " [") {
            identity.name = String(identity.name[..<suffix.lowerBound])
        }
        if let data = txtRecord ?? service.txtRecordData() {
            let records = NetService.dictionary(fromTXTRecord: data)
            var values: [String: String] = [:]
            for (key, data) in records {
                guard let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !value.isEmpty, value.count <= 120,
                      value.rangeOfCharacter(from: .controlCharacters) == nil else { continue }
                values[key.lowercased()] = value
            }
            identity.manufacturer = values["manufacturer"] ?? values["mfg"] ?? values["vendor"]
            identity.model = values["model"] ?? values["product"] ?? values["ty"]
        }
        identities["\(service.domain)\(service.type)\(service.name)@\(host)"] = identity
        for index in devices.indices where !devices[index].endpoints.isDisjoint(with: identity.endpoints) {
            enrich(&devices[index], with: identity)
        }
    }

    private static func firstIPAddress(from addresses: [Data]?) -> String? {
        guard let addresses, !addresses.isEmpty else { return nil }
        let preferredAddresses = addresses.sorted { left, right in
            let leftIsIPv4 = left.withUnsafeBytes { $0.count > 1 && $0[1] == UInt8(AF_INET) }
            let rightIsIPv4 = right.withUnsafeBytes { $0.count > 1 && $0[1] == UInt8(AF_INET) }
            return leftIsIPv4 && !rightIsIPv4
        }
        for data in preferredAddresses {
            let result: String? = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                guard ptr.count >= MemoryLayout<sockaddr>.size, let base = ptr.baseAddress else { return nil }
                let sa = base.assumingMemoryBound(to: sockaddr.self).pointee
                switch Int32(sa.sa_family) {
                case AF_INET:
                    guard ptr.count >= MemoryLayout<sockaddr_in>.size else { return nil }
                    let sin = base.assumingMemoryBound(to: sockaddr_in.self).pointee
                    var addr = sin.sin_addr
                    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                    return String(cString: buffer)
                case AF_INET6:
                    guard ptr.count >= MemoryLayout<sockaddr_in6>.size else { return nil }
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

extension LDCDiscoveryService: NetServiceBrowserDelegate, NetServiceDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard browsers.contains(where: { $0 === browser }) else { return }
        service.delegate = self
        if services.contains(where: { $0 === service }) == false {
            services.append(service)
        }
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        guard browsers.contains(where: { $0 === browser }) else { return }
        service.delegate = nil
        service.stopMonitoring()
        service.stop()
        services.removeAll(where: { $0 === service })
        if service.type == "_ssh._tcp.", let hostName = service.hostName {
            if let idx = devices.firstIndex(where: { $0.host == hostName && $0.port == service.port }) {
                devices.remove(at: idx)
            }
        }
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        updateIdentity(from: sender)
        if sender.type != "_ssh._tcp." {
            sender.startMonitoring()
            return
        }
        guard let hostName = sender.hostName else { return }
        sender.startMonitoring()
        let ip = Self.firstIPAddress(from: sender.addresses)
        let item = LDCDiscoveredDevice(name: sender.name, host: hostName, port: sender.port, ip: ip, source: .bonjour, latencyMs: nil)
        merge(item)
    }

    func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        updateIdentity(from: sender, txtRecord: data)
    }
}
