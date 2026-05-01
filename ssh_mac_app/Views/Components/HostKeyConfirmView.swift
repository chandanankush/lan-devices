import SwiftUI

struct HostKeyConfirmView: View {
    let host: String
    let port: Int
    let keys: [HostKey]
    let errorMessage: String?
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trust Host Key?").font(.title).bold()
            Text("Host: \(host):\(port)")
                .font(.body)
                .foregroundStyle(Color.primary.opacity(0.65))

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else {
                if keys.isEmpty {
                    Text("No host keys were found.")
                        .foregroundStyle(Color.primary.opacity(0.65))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Discovered keys and fingerprints:").font(.headline)
                        ForEach(keys) { key in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Type: \(key.type)")
                                Text("Fingerprint: \(key.fingerprint)")
                                    .font(.system(.body, design: .monospaced))
                            }
                            .padding(8)
                            .background(.quaternary.opacity(0.3))
                            .cornerRadius(6)
                        }
                    }
                }
                Text("Ensure this matches the device's displayed fingerprint.")
                    .font(.callout)
                    .foregroundStyle(Color.primary.opacity(0.65))
            }

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Trust & Save") { onConfirm() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(errorMessage != nil)
            }
        }
        .padding(20)
        .frame(minWidth: 520)
    }
}

