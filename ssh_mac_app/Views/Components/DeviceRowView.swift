import SwiftUI

struct DeviceRowView: View {
    @EnvironmentObject var repo: DeviceRepository
    let device: Device
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            StatusDot(status: device.status)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.title3).bold()
                    .foregroundStyle(device.status == .unreachable
                        ? device.status.color(for: colorScheme)
                        : Color.primary)
                Text("\(device.username)@\(device.host):\(device.port)")
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.65))
            }

            Spacer()

            statusBadge

            actionButtons
                .opacity(device.status == .unreachable ? 0.4 : 1.0)
        }
        .padding(.vertical, 8)
    }

    private var statusBadge: some View {
        let color = device.status.color(for: colorScheme)
        return Text(device.status.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private var actionButtons: some View {
        HStack(spacing: 2) {
            actionButton(icon: "terminal", help: "Open in Terminal") {
                repo.openInTerminal(device)
            }
            actionButton(icon: "arrow.clockwise", help: "Restart via SSH") {
                Task { await repo.restart(device) }
            }
            actionButton(icon: "power", help: "Shutdown via SSH", role: .destructive) {
                Task { await repo.shutdown(device) }
            }
        }
    }

    private func actionButton(
        icon: String,
        help: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role) { action() } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}
