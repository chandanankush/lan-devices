import SwiftUI

struct StatusDot: View {
    let status: DeviceStatus
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Circle()
            .fill(accessibleColor)
            .frame(width: 15, height: 15)
            .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
            .help(status.label)
    }

    private var accessibleColor: Color { status.color(for: colorScheme) }
}

