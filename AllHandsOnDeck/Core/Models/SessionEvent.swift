import Foundation

/// Wire-level events exchanged via SessionTransport. Designed so that
/// Multipeer / WebSocket implementations can encode them as JSON.
enum SessionEvent: Codable, Sendable, Equatable {
    /// Host broadcasts the canonical session settings (timer, trigger
    /// permission, etc.) so viewers can reflect them in their UI.
    case sessionMetadata(PhotoSession)
    case participantJoined(Participant)
    case participantLeft(participantID: String)
    case participantReadyChanged(participantID: String, isReady: Bool)
    case previewFrame(jpeg: Data, capturedAt: Date)
    case countdownStarted(photoAt: Date, duration: Int, startedBy: String)
    case countdownCancelled(by: String)
    case captureRequested(by: String)
    case captureNowRequested(by: String)
    case captureApproved(approvedBy: String)
    case captureDenied(deniedBy: String)
    case photoCaptured(at: Date)
    case finalPhotoAvailable(photoID: String, jpeg: Data)
    case reactionSent(by: String, reaction: String)
    case sessionEnded

    var isMediaEvent: Bool {
        switch self {
        case .previewFrame, .finalPhotoAvailable: return true
        default: return false
        }
    }
}
