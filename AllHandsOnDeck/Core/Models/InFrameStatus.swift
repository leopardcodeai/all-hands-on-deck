import Foundation

/// Snapshot of how the group is sitting in the frame, derived from face
/// detection on the live preview. Surfaced to the host UI as a hint chip.
struct InFrameStatus: Equatable, Sendable {
    enum Verdict: Equatable, Sendable {
        case noFaces           // empty scene
        case allInside         // every detected face fully in the safe area
        case someClipped       // at least one face touches the safe-area edge
        case skewedLeft        // group center sits well left of frame center
        case skewedRight
        case tooHigh           // group center too high (heads near top)
        case tooLow
    }

    let verdict: Verdict
    let faceCount: Int
    let updatedAt: Date

    var headline: String {
        switch verdict {
        case .noFaces:      return String(localized: "inframe.noFaces")
        case .allInside:    return String(localized: "inframe.allInside")
        case .someClipped:  return String(localized: "inframe.someClipped")
        case .skewedLeft:   return String(localized: "inframe.skewedLeft")
        case .skewedRight:  return String(localized: "inframe.skewedRight")
        case .tooHigh:      return String(localized: "inframe.tooHigh")
        case .tooLow:       return String(localized: "inframe.tooLow")
        }
    }

    var symbol: String {
        switch verdict {
        case .noFaces:      return "person.slash"
        case .allInside:    return "checkmark.circle.fill"
        case .someClipped:  return "scissors"
        case .skewedLeft:   return "arrow.left"
        case .skewedRight:  return "arrow.right"
        case .tooHigh:      return "arrow.up"
        case .tooLow:       return "arrow.down"
        }
    }

    /// Should the chip celebrate or warn?
    var isHappy: Bool { verdict == .allInside }
}
