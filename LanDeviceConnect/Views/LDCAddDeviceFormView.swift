import SwiftUI

struct LDCAddDeviceFormView: View {
    @Binding var name: String
    @Binding var host: String
    @Binding var port: Int
    @Binding var username: String
    @Binding var password: String
    @Binding var usePasswordAuth: Bool
    @Binding var sshKeyPath: String
    @Binding var acceptNewHostKey: Bool

    var onSave: (LDCDevice) -> Void
    var onCancel: () -> Void

    @State private var showTrustSheet: Bool = false
    @State private var scannedKeys: [LDCHostKey] = []
    @State private var scanError: String?
    @State private var confirmedDevice: LDCDevice?

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
                Button("Cancel", action: onCancel)
                Button("Save") { Task { await tappedSave() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(.trailing, 8)
        .sheet(isPresented: $showTrustSheet, onDismiss: saveConfirmedDevice) {
            LDCHostKeyConfirmView(
                host: host,
                port: port,
                keys: scannedKeys,
                errorMessage: scanError,
                onConfirm: {
                    confirmedDevice = makeDevice()
                    showTrustSheet = false
                },
                onCancel: { showTrustSheet = false }
            )
        }
    }

    private var form: some View {
        Form {
            LabeledContent("Name") {
                TextField("Name", text: $name, prompt: Text("server-pc"))
                    .labelsHidden()
                    .styledField()
            }
            LabeledContent("Host/IP") {
                TextField("Host/IP", text: $host, prompt: Text("192.168.0.10 or host.local"))
                    .labelsHidden()
                    .styledField()
            }
            LabeledContent("Port") {
                TextField("Port", value: $port, formatter: portFormatter)
                    .labelsHidden()
                    .styledField()
                    .frame(width: 104)
            }
            LabeledContent("Username") {
                TextField("Username", text: $username, prompt: Text("user"))
                    .labelsHidden()
                    .styledField()
            }
            Toggle("Use password authentication", isOn: $usePasswordAuth)
                .toggleStyle(LDCAccessibleCheckbox())
                .padding(.top, 6)
            if usePasswordAuth {
                LabeledContent("Password") {
                    SecureField("Password", text: $password, prompt: Text("Password"))
                        .labelsHidden()
                        .styledField()
                }
            } else {
                LabeledContent("SSH Key Path") {
                    TextField("SSH Key Path", text: $sshKeyPath, prompt: Text("~/.ssh/id_rsa"))
                        .labelsHidden()
                        .styledField()
                }
            }
            Toggle("Trust host key on first connect", isOn: $acceptNewHostKey)
                .help("Adds the server host key to known_hosts on first connection (OpenSSH accept-new).")
                .toggleStyle(LDCAccessibleCheckbox())
                .padding(.top, 6)
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

    // Return to the device list only after the confirmation sheet has dismissed.
    private func saveConfirmedDevice() {
        guard let device = confirmedDevice else { return }
        confirmedDevice = nil
        onSave(device)
    }

    private func tappedSave() async {
        guard acceptNewHostKey else {
            onSave(makeDevice())
            return
        }
        do {
            let keys = try await LDCHostKeyService.scan(host: host, port: port)
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
private struct LDCAccessibleCheckbox: ToggleStyle {
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
