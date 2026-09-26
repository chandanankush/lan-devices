import Foundation
import Darwin
import dnssd

// DNS-SD keeps lookups asynchronous and cancellable, unlike blocking getnameinfo.
@MainActor
final class LDCReverseDNSResolver {
    private var references: [DNSServiceRef] = []
    private var continuation: CheckedContinuation<String?, Never>?
    private var timeoutTask: Task<Void, Never>?

    func lookup(address: String, timeout: TimeInterval = 2) async -> String? {
        guard let query = Self.reverseName(for: address), !Task.isCancelled else { return nil }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                guard !Task.isCancelled else { finish(nil); return }
                // Try the configured DNS resolver and multicast LAN responders concurrently.
                for flags in [DNSServiceFlags(0), DNSServiceFlags(kDNSServiceFlagsForceMulticast)] {
                    var reference: DNSServiceRef?
                    let error = DNSServiceQueryRecord(&reference, flags, 0, query,
                        UInt16(kDNSServiceType_PTR), UInt16(kDNSServiceClass_IN),
                        { _, flags, _, error, _, _, _, length, data, _, context in
                            guard let context else { return }
                            let resolver = Unmanaged<LDCReverseDNSResolver>.fromOpaque(context).takeUnretainedValue()
                            // DNSServiceSetDispatchQueue delivers on the main queue.
                            MainActor.assumeIsolated {
                                guard error == kDNSServiceErr_NoError,
                                      flags & DNSServiceFlags(kDNSServiceFlagsAdd) != 0,
                                      let data, length > 0 else { return }
                                let bytes = Data(bytes: data, count: Int(length))
                                if let hostname = LDCReverseDNSResolver.hostname(fromPTR: bytes) { resolver.finish(hostname) }
                            }
                        }, Unmanaged.passUnretained(self).toOpaque())
                    if error == kDNSServiceErr_NoError, let reference {
                        if DNSServiceSetDispatchQueue(reference, .main) == kDNSServiceErr_NoError {
                            references.append(reference)
                        } else { DNSServiceRefDeallocate(reference) }
                    }
                }
                guard !references.isEmpty else { finish(nil); return }
                timeoutTask = Task { @MainActor [weak self] in
                    do { try await Task.sleep(nanoseconds: UInt64(max(0, timeout) * 1_000_000_000)) }
                    catch { return }
                    self?.finish(nil)
                }
            }
        } onCancel: {
            Task { @MainActor in self.finish(nil) }
        }
    }

    private func finish(_ hostname: String?) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        for reference in references { DNSServiceRefDeallocate(reference) }
        references.removeAll()
        continuation.resume(returning: hostname)
    }

    static func reverseName(for address: String) -> String? {
        var ipv4 = in_addr()
        if inet_pton(AF_INET, address, &ipv4) == 1 {
            return address.split(separator: ".").reversed().joined(separator: ".") + ".in-addr.arpa."
        }
        var ipv6 = in6_addr()
        guard inet_pton(AF_INET6, address, &ipv6) == 1 else { return nil }
        let hex = withUnsafeBytes(of: &ipv6) { $0.map { String(format: "%02x", $0) }.joined() }
        return hex.reversed().map(String.init).joined(separator: ".") + ".ip6.arpa."
    }

    static func hostname(fromPTR data: Data) -> String? {
        let bytes = [UInt8](data)
        var labels: [String] = []
        var offset = 0
        while offset < bytes.count {
            let length = Int(bytes[offset])
            offset += 1
            if length == 0 {
                guard offset == bytes.count, !labels.isEmpty else { return nil }
                return labels.joined(separator: ".")
            }
            guard length <= 63, offset + length < bytes.count,
                  let label = String(bytes: bytes[offset..<(offset + length)], encoding: .utf8),
                  !label.isEmpty, label.rangeOfCharacter(from: .controlCharacters) == nil else { return nil }
            labels.append(label)
            offset += length
        }
        return nil
    }
}
