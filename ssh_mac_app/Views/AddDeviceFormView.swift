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
                    .styledField()
            }
            LabeledContent("Host/IP") {
                TextField("192.168.0.10 or host.local", text: $host)
                    .styledField()
            }
            LabeledContent("Port") {
                TextField("22", value: $port, formatter: portFormatter)
                    .styledField()
                    .frame(width: 104)
            }
            LabeledContent("Username") {
                TextField("user", text: $username)
                    .styledField()
            }
            Toggle("Use password authentication", isOn: $usePasswordAuth)
                .toggleStyle(AccessibleCheckbox())
                .padding(.top, 6)
            if usePasswordAuth {
                LabeledContent("Password") {
                    SecureField("Password", text: $password)
                        .styledField()
                }
            } else {
                LabeledContent("SSH Key Path") {
                    TextField("~/.ssh/id_rsa", text: $sshKeyPath)
                        .styledField()
                }
            }
            Toggle("Trust host key on first connect", isOn: $acceptNewHostKey)
                .help("Adds the server host key to known_hosts on first connection (OpenSSH accept-new).")
                .toggleStyle(AccessibleCheckbox())
                .padding(.top, 6)
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

// MARK: - Private form styles

private extension View {
    // Replaces .roundedBorder with explicit background + high-contrast border.
    // .roundedBorder border in dark mode is ~1.3:1 against the window — effectively invisible.
    // This border renders at ~4.3:1 in both light and dark. (Color.primary.opacity(0.45))
    func styledField() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.45), lineWidth: 1)
            )
    }
}

// Native macOS Toggle checkbox border in dark mode is ~1.3:1 — invisible unless focused.
// This custom style draws a visible 1.5pt border at ~4.3:1 in both modes.
private struct AccessibleCheckbox: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(configuration.isOn
                            ? Color.accentColor
                            : Color(nsColor: .controlBackgroundColor))
                        .frame(width: 18, height: 18)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            configuration.isOn ? Color.accentColor : Color.primary.opacity(0.45),
                            lineWidth: 1.5
                        )
                        .frame(width: 18, height: 18)
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                configuration.label
                    .font(.body)
                    .foregroundStyle(Color.primary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
