import Foundation
import SwiftUI
import Darwin
import dnssd

private enum LDCDiscoveryTestFailure: Error { case assertion(String) }

private final class LDCTestNetService: NetService {
    private let resolvedHost: String
    private let resolvedIP: String
    private let record: Data?
    init(name: String, host: String, ip: String, type: String = "_ssh._tcp.", port: Int = 22, txt: [String: Data] = [:]) {
        resolvedHost = host
        resolvedIP = ip
        record = NetService.data(fromTXTRecord: txt)
        super.init(domain: "local.", type: type, name: name, port: Int32(port))
    }
    override var hostName: String? { resolvedHost }
    override var addresses: [Data]? {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        inet_pton(AF_INET, resolvedIP, &address.sin_addr)
        return [withUnsafeBytes(of: &address) { Data($0) }]
    }
    override func txtRecordData() -> Data? { record }
    override func startMonitoring() {}
    override func stopMonitoring() {}
}

@main
struct LDCDiscoveryTests {
    @MainActor
    static func main() async throws {
        let discovery = LDCDiscoveryService()
        let ipResult = LDCTestNetService(name: "192.0.2.7", host: "192.0.2.7", ip: "192.0.2.7")
        discovery.netServiceDidResolveAddress(ipResult)
        let originalID = discovery.devices[0].id
        let namedResult = LDCTestNetService(name: "Office Mac", host: "office-mac.local.", ip: "192.0.2.7")
        discovery.netServiceDidResolveAddress(namedResult)
        try require(discovery.devices.count == 1, "IP and Bonjour results for the same SSH endpoint must merge")
        try require(discovery.devices[0].name == "Office Mac", "A resolved name must replace an IP-only name")
        try require(discovery.devices[0].host == "office-mac.local.", "Use the resolved hostname for prefilling")
        try require(discovery.devices[0].id == originalID, "Enrichment must preserve the sidebar row identity")
        discovery.netServiceDidResolveAddress(ipResult)
        try require(discovery.devices[0].name == "Office Mac", "Later IP-only results must not erase the name")
        print("PASS: discovery merges and enriches matching endpoints")

        let reverseNamed = LDCDiscoveredDevice(name: "lab-linux.local", host: "192.0.2.9", port: 22, ip: "192.0.2.9", source: .subnet, latencyMs: 4)
        discovery.merge(reverseNamed)
        discovery.netServiceDidResolveAddress(LDCTestNetService(name: "lab-linux.local.", host: "lab-linux.local.", ip: "192.0.2.9"))
        try require(discovery.devices.last?.name == "lab-linux.local.", "A hostname is a valid display name even when it matches the connection host")

        let metadata = LDCTestNetService(name: "Office Mac", host: "office-mac.local.", ip: "192.0.2.7", type: "_device-info._tcp.", port: 0, txt: ["manufacturer": Data("Example Hardware".utf8), "model": Data("Workstation 3".utf8)])
        discovery.netServiceDidResolveAddress(metadata)
        try require(discovery.devices.count == 2, "Metadata services must not add non-SSH devices")
        try require(discovery.devices[0].manufacturer == "Example Hardware", "Advertised manufacturer should enrich the SSH endpoint")
        try require(discovery.devices[0].model == "Workstation 3", "Advertised model should enrich the SSH endpoint")
        print("PASS: advertised metadata enriches SSH hosts only")

        let earlyMetadata = LDCTestNetService(name: "NAS", host: "nas.local.", ip: "192.0.2.11", type: "_smb._tcp.", port: 445,
            txt: ["MFG": Data("Example NAS".utf8), "MODEL": Data("Storage 4".utf8)])
        discovery.netServiceDidResolveAddress(earlyMetadata)
        try require(discovery.devices.count == 2, "An SMB advertisement alone must not be listed as an SSH host")
        discovery.merge(LDCDiscoveredDevice(name: "192.0.2.11", host: "192.0.2.11", port: 22, ip: "192.0.2.11", source: .subnet, latencyMs: 8))
        try require(discovery.devices.last?.name == "NAS", "Previously advertised names must enrich later subnet results")
        try require(discovery.devices.last?.manufacturer == "Example NAS", "TXT keys must be interpreted without case sensitivity")
        try require(discovery.devices.last?.port == 22, "Metadata must not replace the SSH port with SMB's port")
        discovery.merge(LDCDiscoveredDevice(name: "192.0.2.11", host: "192.0.2.11", port: 2222, ip: "192.0.2.11", source: .subnet, latencyMs: 8))
        try require(discovery.devices.count == 4, "Different SSH ports on the same host are separate endpoints")
        let malformed = LDCTestNetService(name: "Unidentified", host: "unknown.local.", ip: "192.0.2.21", txt: ["manufacturer": Data([0xff]), "model": Data("bad\nmodel".utf8)])
        discovery.netServiceDidResolveAddress(malformed)
        try require(discovery.devices.last?.manufacturer == nil && discovery.devices.last?.model == nil, "Invalid TXT text must not be displayed")
        discovery.netService(earlyMetadata, didUpdateTXTRecord: NetService.data(fromTXTRecord: ["model": Data("Storage 5".utf8)]))
        try require(discovery.devices[2].model == "Storage 5", "TXT callbacks must use the new supplied metadata")
        print("PASS: metadata ordering, ports, invalid TXT records, and updates")
        try await reverseDNS()

    }
    @MainActor
    private static func reverseDNS() async throws {
        try require(LDCReverseDNSResolver.reverseName(for: "192.0.2.88") == "88.2.0.192.in-addr.arpa.", "IPv4 PTR query must reverse all octets")
        try require(LDCReverseDNSResolver.reverseName(for: "::1") == "1." + String(repeating: "0.", count: 31) + "ip6.arpa.", "IPv6 PTR query must reverse all nibbles")
        try require(LDCReverseDNSResolver.reverseName(for: "server.local") == nil, "Only numeric addresses can form PTR queries")
        let wireName = Data([7] + Array("testbox".utf8) + [5] + Array("local".utf8) + [0])
        try require(LDCReverseDNSResolver.hostname(fromPTR: wireName) == "testbox.local", "PTR wire labels must decode into a display hostname")
        for invalid in [Data(), Data([0]), Data([4, 65]), Data([0xc0, 0]), Data([1, 10, 0])] {
            try require(LDCReverseDNSResolver.hostname(fromPTR: invalid) == nil, "Malformed PTR records must be ignored")
        }

        // Publish a real local-only PTR record; no LAN device or external DNS is required.
        var publisher: DNSServiceRef?
        try require(DNSServiceCreateConnection(&publisher) == kDNSServiceErr_NoError, "Local DNS-SD publisher must start")
        guard let publisher else { throw LDCDiscoveryTestFailure.assertion("Publisher missing") }
        defer { DNSServiceRefDeallocate(publisher) }
        try require(DNSServiceSetDispatchQueue(publisher, .main) == kDNSServiceErr_NoError, "Publisher must run on the main queue")
        var record: DNSRecordRef?
        let registered = wireName.withUnsafeBytes { bytes in
            DNSServiceRegisterRecord(publisher, &record, DNSServiceFlags(kDNSServiceFlagsShared),
                UInt32(kDNSServiceInterfaceIndexLocalOnly), "88.2.0.192.in-addr.arpa.",
                UInt16(kDNSServiceType_PTR), UInt16(kDNSServiceClass_IN), UInt16(bytes.count), bytes.baseAddress, 60,
                { _, _, _, _, _ in }, nil)
        }
        try require(registered == kDNSServiceErr_NoError, "Test PTR record must register")
        let resolved = await LDCReverseDNSResolver().lookup(address: "192.0.2.88")
        try require(resolved == "testbox.local", "The background DNS-SD lookup must return a published hostname")
        print("PASS: real asynchronous reverse DNS lookup")

        let started = Date()
        let missing = await LDCReverseDNSResolver().lookup(address: "192.0.2.89", timeout: 0.05)
        try require(missing == nil && Date().timeIntervalSince(started) < 1, "Missing PTR records must time out promptly")
        let cancelled = Task { @MainActor in await LDCReverseDNSResolver().lookup(address: "192.0.2.90", timeout: 5) }
        await Task.yield()
        cancelled.cancel()
        let result = await cancelled.value
        try require(result == nil, "Cancelled hostname lookup must finish without a name")
        print("PASS: DNS lookup timeout and cancellation")
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw LDCDiscoveryTestFailure.assertion(message) }
    }
}
