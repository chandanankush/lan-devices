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
            Text("Trust Host Key?").font(.title2).bold()
            Text("Host: \(host):\(port)")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else {
                if keys.isEmpty {
                    Text("No host keys were found.")
                        .foregroundStyle(.secondary)
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
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

