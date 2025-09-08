import SwiftUI

struct SudoPasswordPromptView: View {
    let device: Device
    let action: DeviceAction
    var onSubmit: (_ password: String, _ remember: Bool) -> Void
    var onCancel: () -> Void

    @State private var password: String = ""
    @State private var remember: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Authentication Required").font(.title2).bold()
            Text("Enter sudo password for \(device.username)@\(device.host)")
                .font(.callout)
                .foregroundStyle(.secondary)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 320)
            Toggle("Remember this password for this device", isOn: $remember)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button(action == .shutdown ? "Shutdown" : "Restart") {
                    onSubmit(password, remember)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 400)
    }
}

