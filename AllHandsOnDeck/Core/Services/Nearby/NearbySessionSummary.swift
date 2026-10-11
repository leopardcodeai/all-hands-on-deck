import Foundation

/// What we surface to the UI when a host is discovered nearby.
///
/// Note: we deliberately don't expose `MCPeerID` to the UI — the viewer's
/// MultipeerSessionTransport rebrowses on its own and matches by sessionId,
/// so the UI layer never has to import MultipeerConnectivity.
struct NearbySessionSummary: Identifiable, Hashable {
    let sessionId: String
    let hostName: String
    let triggerPermission: TriggerPermission
    let timerDuration: Int
    let discoveredAt: Date

    var id: String { sessionId }

    init?(discoveryInfo info: [String: String]?, fallbackPeerName: String) {
        guard let info, let id = info["sessionId"] else { return nil }
        self.sessionId = id
        self.hostName = info["hostName"] ?? fallbackPeerName
        self.triggerPermission = TriggerPermission(rawValue: info["trigger"] ?? "") ?? .hostOnly
        self.timerDuration = Int(info["timer"] ?? "10") ?? 10
        self.discoveredAt = Date()
    }

    /// Construct a stub PhotoSession so the viewer flow can drive transport
    /// connection. Server-of-truth values are then overwritten by the host's
    /// `.sessionMetadata` event after the MCSession connects.
    func makePhotoSession() -> PhotoSession {
        PhotoSession(
            id: sessionId,
            hostName: hostName,
            ttlMinutes: 30,
            timerDuration: timerDuration,
            triggerPermission: triggerPermission
        )
    }
}
