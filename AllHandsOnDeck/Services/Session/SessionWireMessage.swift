import Foundation

/// Wire-level envelope that wraps every payload sent between peers.
///
/// We deliberately keep the envelope tiny — just enough to disambiguate
/// stale or out-of-band messages — and let `SessionEvent` carry the
/// semantic payload (which is already Codable and supports binary blobs
/// for preview frames and the final photo).
struct SessionWireMessage: Codable, Sendable {
    let sessionId: String
    let senderId: String
    let createdAt: Date
    let event: SessionEvent

    /// Coarse routing kind, derived from the wrapped event. Lets the
    /// transport pick reliable vs. unreliable delivery without re-encoding.
    enum Kind: CustomStringConvertible {
        case metadata
        case event
        case previewFrame
        case finalPhoto
        case triggerRequest
        case reaction

        var description: String { String(describing: self) }
    }

    var kind: Kind {
        switch event {
        case .sessionMetadata: return .metadata
        case .previewFrame: return .previewFrame
        case .finalPhotoAvailable: return .finalPhoto
        case .captureRequested, .captureNowRequested: return .triggerRequest
        case .reactionSent: return .reaction
        default: return .event
        }
    }
}

extension SessionWireMessage {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> SessionWireMessage {
        try Self.decoder.decode(SessionWireMessage.self, from: data)
    }
}
