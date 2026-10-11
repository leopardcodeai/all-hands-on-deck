import Foundation

/// Who is allowed to start the countdown / capture flow.
enum TriggerPermission: String, Codable, Hashable, CaseIterable, Identifiable, Sendable {
    /// Only the host may start the timer.
    case hostOnly
    /// Any participant may start the timer directly.
    case everyoneCanStartTimer
    /// Viewers may request a capture; the host must approve.
    case viewersCanRequest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hostOnly: return String(localized: "trigger.hostOnly.title")
        case .everyoneCanStartTimer: return String(localized: "trigger.everyoneCanStartTimer.title")
        case .viewersCanRequest: return String(localized: "trigger.viewersCanRequest.title")
        }
    }

    var subtitle: String {
        switch self {
        case .hostOnly: return String(localized: "trigger.hostOnly.subtitle")
        case .everyoneCanStartTimer: return String(localized: "trigger.everyoneCanStartTimer.subtitle")
        case .viewersCanRequest: return String(localized: "trigger.viewersCanRequest.subtitle")
        }
    }

    var symbol: String {
        switch self {
        case .hostOnly: return "person.fill"
        case .everyoneCanStartTimer: return "person.3.fill"
        case .viewersCanRequest: return "hand.raised.fill"
        }
    }
}
