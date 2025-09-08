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

    private var sidebar: some View {
        List(selection: $selected) {
            Section("Discovered on LAN") {
                ForEach(discovery.devices) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name.isEmpty ? hostDisplay(item.host) : item.name)
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("\(hostDisplay(item.host)):\(item.port)")
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
}

private func hostDisplay(_ host: String) -> String {
    host.hasSuffix(".") ? String(host.dropLast()) : host
}

