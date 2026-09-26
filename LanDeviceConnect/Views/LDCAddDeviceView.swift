import SwiftUI

struct LDCAddDeviceView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: Int = 22
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var usePasswordAuth: Bool = false
    @State private var sshKeyPath: String = ""
    @State private var acceptNewHostKey: Bool = true
    @State private var showTrustSheet: Bool = false
    @State private var scanning: Bool = false
    @State private var scannedKeys: [LDCHostKey] = []
    @State private var scanError: String?
    @State private var pendingDevice: LDCDevice?
    private let portFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimum = 1
        f.maximum = 65535
        f.allowsFloats = false
        return f
    }()

    @StateObject private var discovery = LDCDiscoveryService()

    var onSave: (LDCDevice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Device").font(.title).bold()

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Discovered on LAN").font(.headline)
                        Spacer()
                        if discovery.isScanning { ProgressView().scaleEffect(0.6) }
                        Button {
                            discovery.rescan()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Rescan subnet for SSH")
                        .buttonStyle(.borderless)
                    }
                    discoveryList
                        .frame(minHeight: 180)
                }
                Divider().frame(height: 260)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Manual Entry").font(.headline)
                    form
                    HStack {
                        Spacer()
                        Button("Cancel") { dismiss() }
                        Button("Save") { Task { await tappedSave() } }
                            .keyboardShortcut(.defaultAction)
                            .disabled(!canSave)
                    }
                }
                .frame(minWidth: 360, idealWidth: 390)
            }
        }
        .padding(20)
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
        .sheet(isPresented: $showTrustSheet) {
            LDCHostKeyConfirmView(
                host: host,
                port: port,
                keys: scannedKeys,
                errorMessage: scanError,
                onConfirm: {
                    if let d = pendingDevice {
                        onSave(d)
                    }
                    showTrustSheet = false
                    dismiss()
                },
                onCancel: {
                    showTrustSheet = false
                }
            )
        }
    }

    private var discoveryList: some View {
        List(discovery.devices) { item in
            LDCDiscoveredDeviceRow(item: item)
            .contentShape(Rectangle())
            .onTapGesture {
                self.name = item.name.isEmpty ? hostDisplay(item.host) : item.name
                self.host = item.host
                self.port = item.port
            }
        }
        .listStyle(.inset)
        .overlay(alignment: .center) {
            if discovery.devices.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Searching for SSH services…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var form: some View {
        Form {
            LabeledContent("Name") {
                TextField("Name", text: $name, prompt: Text("server-pc"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Host/IP") {
                TextField("Host/IP", text: $host, prompt: Text("192.168.0.10 or host.local"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Port") {
                TextField("Port", value: $port, formatter: portFormatter)
                    .labelsHidden()
                    .frame(width: 90)
            }
            LabeledContent("Username") {
                TextField("Username", text: $username, prompt: Text("user"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
            }
            Toggle("Use password authentication", isOn: $usePasswordAuth)
                .lineLimit(2)
                .padding(.top, 2)
            if usePasswordAuth {
                LabeledContent("Password") {
                    SecureField("Password", text: $password, prompt: Text("Password"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                LabeledContent("SSH Key Path") {
                    TextField("SSH Key Path", text: $sshKeyPath, prompt: Text("~/.ssh/id_rsa"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                }
            }
            Toggle("Trust host key on first connect", isOn: $acceptNewHostKey)
                .help("Adds the server host key to known_hosts on first connection (OpenSSH accept-new).")
                .lineLimit(2)
                .padding(.top, 2)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        port > 0
    }

    private func makeDevice() -> LDCDevice {
        LDCDevice(
            name: name,
            host: host,
            port: port,
            username: username,
            password: usePasswordAuth ? password : nil,
            usePasswordAuth: usePasswordAuth,
            sshKeyPath: usePasswordAuth ? nil : (sshKeyPath.isEmpty ? nil : sshKeyPath),
            acceptNewHostKey: acceptNewHostKey,
            status: .unknown
        )
    }

    private func tappedSave() async {
        let device = makeDevice()
        guard acceptNewHostKey else {
            onSave(device)
            dismiss()
            return
        }
        scanning = true
        do {
            let keys = try await LDCHostKeyService.scan(host: host, port: port)
            scannedKeys = keys
            scanError = nil
        } catch {
            scannedKeys = []
            scanError = error.localizedDescription
        }
        pendingDevice = device
        showTrustSheet = true
        scanning = false
    }
}

private func hostDisplay(_ host: String) -> String {
    host.hasSuffix(".") ? String(host.dropLast()) : host
}
