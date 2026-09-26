import SwiftUI
import AppKit

struct LDCAddDeviceFlowView: View {
    @EnvironmentObject var repo: LDCDeviceRepository
    @Environment(\.dismiss) private var dismiss

    @State private var windowReference = LDCAddDeviceWindowReference()
    @StateObject private var discovery = LDCDiscoveryService()
    @State private var selected: LDCDiscoveredDevice?

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
                    closeWindow()
                },
                onCancel: closeWindow
            )
            .padding(.horizontal)
        }
        .background(LDCAddDeviceWindowAccessor(reference: windowReference).frame(width: 0, height: 0))
        .navigationTitle("Add Device")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: closeWindow) {
                    Image(systemName: "xmark")
                }
                .help("Close Add Device")
                .accessibilityLabel("Close Add Device")
                .keyboardShortcut(.cancelAction)
            }
        }
        .frame(minWidth: 720, minHeight: 440)
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
    }

    private func closeWindow() {
        discovery.stop()
        if let window = windowReference.window {
            // Allow any host-key sheet to finish its dismissal before closing its owner.
            DispatchQueue.main.async { [weak window] in window?.performClose(nil) }
        } else {
            dismiss()
        }
    }

    private var filteredDiscoveredDevices: [LDCDiscoveredDevice] {
        let existing = Set(repo.devices.map { "\(normalizeHost($0.host)):\($0.port)" })
        return discovery.devices.filter { !existing.contains("\(normalizeHost($0.host)):\($0.port)") }
    }

    private var sidebar: some View {
        List(selection: $selected) {
            Section("Discovered on LAN") {
                ForEach(filteredDiscoveredDevices) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name.isEmpty ? hostDisplay(item.host) : item.name)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        HStack(spacing: 6) {
                            Text("\(hostDisplay(item.host)):\(item.port)")
                            if let ip = item.ip, ip != hostDisplay(item.host) { Text("• \(ip)") }
                            Text("• \(item.source == .bonjour ? "Bonjour" : "Subnet")")
                            if let ms = item.latencyMs { Text("• ~\(ms) ms") }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.primary.opacity(0.65))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    }
                    .tag(item as LDCDiscoveredDevice?)
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

// Resolve this window specifically; the key window may be the host-key confirmation sheet.
private final class LDCAddDeviceWindowReference {
    weak var window: NSWindow?
}

private struct LDCAddDeviceWindowAccessor: NSViewRepresentable {
    let reference: LDCAddDeviceWindowReference

    func makeNSView(context: Context) -> LDCAddDeviceWindowObserver {
        LDCAddDeviceWindowObserver(reference: reference)
    }

    func updateNSView(_ view: LDCAddDeviceWindowObserver, context: Context) {}
}

private final class LDCAddDeviceWindowObserver: NSView {
    private let reference: LDCAddDeviceWindowReference

    init(reference: LDCAddDeviceWindowReference) {
        self.reference = reference
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reference.window = window
    }
}
