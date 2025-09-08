import Foundation
import SwiftUI

enum DeviceStatus: Int, Codable, CaseIterable {
    case unknown = 0
    case reachable = 1
    case unreachable = 2

    var label: String {
        switch self {
        case .unknown: return "Unknown"
        case .reachable: return "Online"
        case .unreachable: return "Offline"
        }
    }

    var color: Color {
        switch self {
        case .unknown: return .yellow
        case .reachable: return .green
        case .unreachable: return .orange
        }
    }
}

