import Foundation

/// Countdown lifecycle. `running` carries an absolute target date so all clients
/// can compute their own remaining time without per-tick network sync.
enum CountdownState: Equatable, Sendable {
    case idle
    case running(photoAt: Date, duration: Int)
    case capturing
    case completed

    var isActive: Bool {
        switch self {
        case .running, .capturing: return true
        default: return false
        }
    }
}
