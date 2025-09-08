import SwiftUI

struct DeviceRowView: View {
    @EnvironmentObject var repo: DeviceRepository
    let device: Device

    var body: some View {
        HStack(spacing: 12) {
            StatusDot(status: device.status)
            VStack(alignment: .leading) {
                Text(device.name).font(.headline)
                Text("\(device.username)@\(device.host):\(device.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    repo.openInTerminal(device)
                } label: {
                    Image(systemName: "terminal")
                }
                .help("Open in Terminal")

                Button {
                    Task { await repo.restart(device) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Restart via SSH")

                Button(role: .destructive) {
                    Task { await repo.shutdown(device) }
                } label: {
                    Image(systemName: "power")
                }
                .help("Shutdown via SSH")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

