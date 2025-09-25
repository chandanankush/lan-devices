import Foundation
import Network
import Darwin

final class SubnetScanner {
    func primaryIPv4() -> String? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var candidate: String?
        var p = first
        while true {
            let ifa = p.pointee
            guard let sa = ifa.ifa_addr else { break }
            if sa.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: ifa.ifa_name)
                var addr_in = UnsafePointer<sockaddr_in>(OpaquePointer(ifa.ifa_addr)).pointee
                let ip = String(cString: inet_ntoa(addr_in.sin_addr))
                if name.hasPrefix("en"), !ip.hasPrefix("169.254.") {
                    return ip
                }
                if candidate == nil, !ip.hasPrefix("127."), !ip.hasPrefix("169.254.") {
                    candidate = ip
                }
            }
            if let next = ifa.ifa_next { p = next } else { break }
        }
        return candidate
    }

    func addressesIn24(ipv4: String) -> [String] {
        let parts = ipv4.split(separator: ".")
        guard parts.count == 4 else { return [] }
        let base = parts[0] + "." + parts[1] + "." + parts[2]
        var hosts: [String] = []
        for i in 1...254 {
            let h = "\(base).\(i)"
            if h != ipv4 { hosts.append(h) }
        }
        return hosts
    }

    // Scan the subnet for SSH hosts. Now fills in additional fields: ip, source, latencyMs.
    func scanSSH(timeout: TimeInterval = 0.9, limit: Int? = nil) async -> [DiscoveredDevice] {
        guard let ip = primaryIPv4() else { return [] }
        var candidates = addressesIn24(ipv4: ip)
        if let limit, candidates.count > limit { candidates = Array(candidates.prefix(limit)) }

        var found: [DiscoveredDevice] = []
        await withTaskGroup(of: DiscoveredDevice?.self) { group in
            for host in candidates {
                group.addTask {
                    let start = DispatchTime.now().uptimeNanoseconds
                    let status = await StatusChecker.check(host: host, port: 22, timeout: timeout)
                    let end = DispatchTime.now().uptimeNanoseconds
                    let elapsedNs = end &- start
                    let ms = Int(Double(elapsedNs) / 1_000_000.0)
                    if status == .reachable {
                        return DiscoveredDevice(name: host, host: host, port: 22, ip: host, source: .subnet, latencyMs: ms)
                    }
                    return nil
                }
            }
            for await item in group {
                if let dev = item { found.append(dev) }
            }
        }
        // Simple sort by host
        return found.sorted { $0.host < $1.host }
    }
}
