import SwiftUI

struct AddDeviceFlowView: View {
    @EnvironmentObject var repo: DeviceRepository
    @Environment(\.dismiss) private var dismiss

    @StateObject private var discovery = DiscoveryService()
    @State private var selected: DiscoveredDevice?

    // Form state (shared with the form view via bindings)
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: Int = 22
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var usePasswordAuth: Bool = false
    @State private var sshKeyPath: String = ""
    @State private var acceptNewHostKey: Bool = true

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            AddDeviceFormView(
                name: $name,
                host: $host,
                port: $port,
                username: $username,
                password: $password,
                usePasswordAuth: $usePasswordAuth,
                sshKeyPath: $sshKeyPath,
                acceptNewHostKey: $acceptNewHostKey
            ) { newDevice in
                repo.add(newDevice)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Add Device")
        .frame(minWidth: 720, minHeight: 440)
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
    }

    private var filteredDiscoveredDevices: [DiscoveredDevice] {
        let existing = Set(repo.devices.map { "\(normalizeHost($0.host)):\($0.port)" })
        return discovery.devices.filter { !existing.contains("\(normalizeHost($0.host)):\($0.port)") }
    }

    private var sidebar: some View {
        List(selection: $selected) {
            Section("Discovered on LAN") {
                ForEach(filteredDiscoveredDevices) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name.isEmpty ? hostDisplay(item.host) : item.name)
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        HStack(spacing: 6) {
                            Text("\(hostDisplay(item.host)):\(item.port)")
                            if let ip = item.ip, ip != hostDisplay(item.host) { Text("• \(ip)") }
                            Text("• \(item.source == .bonjour ? "Bonjour" : "Subnet")")
                            if let ms = item.latencyMs { Text("• ~\(ms) ms") }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    }
                    .tag(item as DiscoveredDevice?)
                    .onTapGesture {
                        prefill(with: item)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if discovery.isScanning { ProgressView().scaleEffect(0.7) }
            }
            ToolbarItem(placement: .automatic) {
                Button { discovery.rescan() } label: { Image(systemName: "arrow.clockwise") }
            }
        }
    }

    private func prefill(with item: DiscoveredDevice) {
        name = item.name.isEmpty ? hostDisplay(item.host) : item.name
        host = item.host
        port = item.port
    }

    private func normalizeHost(_ s: String) -> String {
        let trimmed = s.hasSuffix(".") ? String(s.dropLast()) : s
        return trimmed.lowercased()
    }
}

private func hostDisplay(_ host: String) -> String {
    host.hasSuffix(".") ? String(host.dropLast()) : host
}
