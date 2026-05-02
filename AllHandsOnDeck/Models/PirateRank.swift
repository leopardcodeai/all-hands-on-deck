import Foundation

enum PirateRank: Int, CaseIterable, Codable {
    case cabinBoy       = 0
    case deckhand       = 1
    case boatswain      = 2
    case gunner         = 3
    case navigator      = 4
    case quartermaster  = 5
    case firstMate      = 6
    case captain        = 7

    // Minimum action points required to hold this rank.
    var threshold: Int {
        switch self {
        case .cabinBoy:      return 0
        case .deckhand:      return 10
        case .boatswain:     return 30
        case .gunner:        return 60
        case .navigator:     return 100
        case .quartermaster: return 150
        case .firstMate:     return 200
        case .captain:       return 300
        }
    }

    var emoji: String {
        switch self {
        case .cabinBoy:      return "🪣"
        case .deckhand:      return "⛵"
        case .boatswain:     return "🪢"
        case .gunner:        return "💣"
        case .navigator:     return "🧭"
        case .quartermaster: return "⚖️"
        case .firstMate:     return "⚓"
        case .captain:       return "🏴‍☠️"
        }
    }

    var title: String {
        switch self {
        case .cabinBoy:      return String(localized: "rank.cabinBoy")
        case .deckhand:      return String(localized: "rank.deckhand")
        case .boatswain:     return String(localized: "rank.boatswain")
        case .gunner:        return String(localized: "rank.gunner")
        case .navigator:     return String(localized: "rank.navigator")
        case .quartermaster: return String(localized: "rank.quartermaster")
        case .firstMate:     return String(localized: "rank.firstMate")
        case .captain:       return String(localized: "rank.captain")
        }
    }

    /// GC achievement identifier for reaching this rank.
    var achievementID: String? {
        switch self {
        case .cabinBoy: return nil
        default: return "rank_\(String(describing: self))"
        }
    }

    static func rank(for points: Int) -> Self {
        Self.allCases.reversed().first { points >= $0.threshold } ?? .cabinBoy
    }

    static func random() -> Self {
        Self.allCases.randomElement() ?? .deckhand
    }
}
