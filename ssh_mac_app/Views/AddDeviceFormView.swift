import SwiftUI

struct AddDeviceFormView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var name: String
    @Binding var host: String
    @Binding var port: Int
    @Binding var username: String
    @Binding var password: String
    @Binding var usePasswordAuth: Bool
    @Binding var sshKeyPath: String
    @Binding var acceptNewHostKey: Bool

    var onSave: (Device) -> Void

    @State private var showTrustSheet: Bool = false
    @State private var scannedKeys: [HostKey] = []
    @State private var scanError: String?

    private let portFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimum = 1
        f.maximum = 65535
        f.allowsFloats = false
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        .padding(.trailing, 8)
        .sheet(isPresented: $showTrustSheet) {
            HostKeyConfirmView(
                host: host,
                port: port,
                keys: scannedKeys,
                errorMessage: scanError,
                onConfirm: {
                    let device = makeDevice()
                    onSave(device)
                    showTrustSheet = false
                    dismiss()
                },
                onCancel: { showTrustSheet = false }
            )
        }
    }

    private var form: some View {
        Form {
            LabeledContent("Name") {
                TextField("server-pc", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Host/IP") {
                TextField("192.168.0.10 or host.local", text: $host)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Port") {
                TextField("22", value: $port, formatter: portFormatter)
                    .frame(width: 90)
            }
            LabeledContent("Username") {
                TextField("user", text: $username)
                    .textFieldStyle(.roundedBorder)
            }
            Toggle("Use password authentication", isOn: $usePasswordAuth)
                .lineLimit(2)
                .padding(.top, 2)
            if usePasswordAuth {
                LabeledContent("Password") {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                LabeledContent("SSH Key Path") {
                    TextField("~/.ssh/id_rsa", text: $sshKeyPath)
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

    private func makeDevice() -> Device {
        Device(
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
        guard acceptNewHostKey else {
            onSave(makeDevice())
            dismiss()
            return
        }
        do {
            let keys = try await HostKeyService.scan(host: host, port: port)
            scannedKeys = keys
            scanError = nil
        } catch {
            scannedKeys = []
            scanError = error.localizedDescription
        }
        showTrustSheet = true
    }
}

