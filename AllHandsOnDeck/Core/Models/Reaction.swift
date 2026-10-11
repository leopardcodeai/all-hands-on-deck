import Foundation

/// One-tap signals viewers send to the host. Wire-side this is just a string
/// inside `SessionEvent.reactionSent`, but we keep the canonical set typed.
enum Reaction: String, CaseIterable, Identifiable, Codable, Sendable {
    case ready          // "Bereit"
    case waitMoment     // "Warte kurz"
    case again          // "Noch mal"
    case cantSeeMe      // "Ich sehe mich nicht"
    case raiseCamera    // "Kamera höher"
    case moveLeft       // "Weiter links"
    case moveRight      // "Weiter rechts"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ready:        return String(localized: "reaction.ready")
        case .waitMoment:   return String(localized: "reaction.waitMoment")
        case .again:        return String(localized: "reaction.again")
        case .cantSeeMe:    return String(localized: "reaction.cantSeeMe")
        case .raiseCamera:  return String(localized: "reaction.raiseCamera")
        case .moveLeft:     return String(localized: "reaction.moveLeft")
        case .moveRight:    return String(localized: "reaction.moveRight")
        }
    }

    var symbol: String {
        switch self {
        case .ready:        return "checkmark.circle.fill"
        case .waitMoment:   return "hourglass"
        case .again:        return "arrow.counterclockwise"
        case .cantSeeMe:    return "eye.slash.fill"
        case .raiseCamera:  return "arrow.up"
        case .moveLeft:     return "arrow.left"
        case .moveRight:    return "arrow.right"
        }
    }

    /// "Action" reactions adjust framing — host gets a louder toast for these.
    var isFramingHint: Bool {
        switch self {
        case .raiseCamera, .moveLeft, .moveRight, .cantSeeMe: return true
        default: return false
        }
    }
}
