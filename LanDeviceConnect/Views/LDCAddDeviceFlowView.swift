import SwiftUI

struct LDCAddDeviceFlowView: View {
    @EnvironmentObject var repo: LDCDeviceRepository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onFinish: () -> Void

    @StateObject private var discovery = LDCDiscoveryService()
    @State private var selected: UUID?
    @State private var selectionRevision = 0
    @State private var showsSelectionFeedback = false

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
                .navigationSplitViewColumnWidth(min: 210, ideal: 260, max: 340)
        } detail: {
            LDCAddDeviceFormView(
                name: $name,
                host: $host,
                port: $port,
                username: $username,
                password: $password,
                usePasswordAuth: $usePasswordAuth,
                sshKeyPath: $sshKeyPath,
                acceptNewHostKey: $acceptNewHostKey,
                onSave: { newDevice in
                    repo.add(newDevice)
                    returnToDevices()
                },
                onCancel: returnToDevices
            )
            .padding(.horizontal)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(showsSelectionFeedback ? 0.4 : 0), lineWidth: 1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, -8)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Add Device")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: returnToDevices) {
                    Label("Devices", systemImage: "chevron.left")
                }
                .help("Back to Devices")
                .accessibilityLabel("Back to Devices")
                .keyboardShortcut(.cancelAction)
            }
        }
        .frame(minWidth: 720, minHeight: 440)
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
        .task(id: selectionRevision) {
            guard selectionRevision > 0, !reduceMotion else { return }
            do { try await Task.sleep(nanoseconds: 300_000_000) }
            catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { showsSelectionFeedback = false }
        }
    }

    private func returnToDevices() {
        discovery.stop()
        onFinish()
    }

    private var filteredDiscoveredDevices: [LDCDiscoveredDevice] {
        let existing = Set(repo.devices.map { "\(normalizeHost($0.host)):\($0.port)" })
        return discovery.devices.filter { device in
            !device.endpoints.contains { existing.contains("\($0):\(device.port)") }
        }
    }

    private var sidebar: some View {
        List(selection: deviceSelection) {
            Section("Discovered on LAN") {
                ForEach(filteredDiscoveredDevices) { item in
                    LDCDiscoveredDeviceRow(item: item, isSelected: selected == item.id)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .tag(item.id)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selected == item.id ? Color.accentColor : Color.clear)
                        )
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

    // Native list selection owns both the highlight and prefill, including keyboard selection.
    private var deviceSelection: Binding<UUID?> {
        Binding(get: { selected }, set: { id in
            guard let item = filteredDiscoveredDevices.first(where: { $0.id == id }) else {
                selected = nil
                return
            }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                selected = item.id
                prefill(with: item)
                showsSelectionFeedback = !reduceMotion
            }
            selectionRevision += 1
        })
    }

    private func prefill(with item: LDCDiscoveredDevice) {
        name = item.name.isEmpty ? hostDisplay(item.host) : item.name
        host = hostDisplay(item.host)
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

struct LDCDiscoveredDeviceRow: View {
    let item: LDCDiscoveredDevice
    var isSelected = false

    private var identification: String {
        [item.manufacturer, item.model].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name.isEmpty ? hostDisplay(item.host) : item.name)
                .font(.headline)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(2)
            if !identification.isEmpty {
                Text(identification)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                    .lineLimit(2)
            }
            Text("\(hostDisplay(item.host)):\(item.port)")
                .font(.caption)
                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let ip = item.ip, ip != hostDisplay(item.host) {
                Text(ip).font(.caption)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
            }
            HStack(spacing: 6) {
                Text(item.source == .bonjour ? "Bonjour" : "Subnet")
                if let ms = item.latencyMs { Text("~\(ms) ms") }
            }
            .font(.caption2)
            .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.secondary.opacity(0.7))
        }
        .padding(.vertical, 3)
        .help([item.name, identification, "\(hostDisplay(item.host)):\(item.port)", item.ip ?? ""]
            .filter { !$0.isEmpty }.joined(separator: "\n"))
    }
}
