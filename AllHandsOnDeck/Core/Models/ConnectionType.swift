import Foundation

/// How a participant is connected to the host session.
enum ConnectionType: String, Codable, Hashable, Sendable {
    case web
    case nativeNearby
    case nativeQR
    case mock

    var label: String {
        switch self {
        case .web: return "Web"
        case .nativeNearby: return "Nearby"
        case .nativeQR: return "QR"
        case .mock: return "Mock"
        }
    }
}
