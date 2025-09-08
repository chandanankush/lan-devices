import SwiftUI

struct StatusDot: View {
    let status: DeviceStatus
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
            .help(status.label)
    }
}

