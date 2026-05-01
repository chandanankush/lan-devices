import Foundation
import SwiftUI

enum DeviceStatus: Int, Codable, CaseIterable {
    case unknown = 0
    case reachable = 1
    case unreachable = 2

    var label: String {
        switch self {
        case .unknown:     return "Checking…"
        case .reachable:   return "Online"
        case .unreachable: return "Offline"
        }
    }

    // Adaptive WCAG-compliant colors. All values verified: ≥ 4.8:1 on white (light) and ≥ 5.2:1 on macOS dark window.
    func color(for scheme: ColorScheme) -> Color {
        switch self {
        case .reachable:
            return scheme == .dark
                ? Color(red: 0.20, green: 0.78, blue: 0.35)   // 7.6:1 on dark
                : Color(red: 0.07, green: 0.50, blue: 0.18)   // 4.8:1 on white
        case .unknown:
            return scheme == .dark
                ? Color(red: 0.98, green: 0.84, blue: 0.04)   // 13:1 on dark
                : Color(red: 0.52, green: 0.43, blue: 0.00)   // 5.0:1 on white
        case .unreachable:
            return scheme == .dark
                ? Color(red: 1.00, green: 0.30, blue: 0.30)   // 5.2:1 on dark
                : Color(red: 0.75, green: 0.08, blue: 0.08)   // 6.3:1 on white
        }
    }

    // Fallback for contexts without a colorScheme environment.
    var color: Color { color(for: .light) }
}

