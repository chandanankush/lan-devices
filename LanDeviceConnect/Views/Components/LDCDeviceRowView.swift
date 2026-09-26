import SwiftUI

struct LDCDeviceRowView: View {
    @EnvironmentObject var repo: LDCDeviceRepository
    let device: LDCDevice
    var onPowerAction: (LDCDeviceAction) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            LDCStatusDot(status: device.status)

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
            Menu {
                Button("Shut Down…", role: .destructive) { onPowerAction(.shutdown) }
                Button("Restart…") { onPowerAction(.restart) }
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Power Actions")
            .accessibilityLabel("Power actions for \(device.name)")
        }
    }

    private func actionButton(
        icon: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button { action() } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}
