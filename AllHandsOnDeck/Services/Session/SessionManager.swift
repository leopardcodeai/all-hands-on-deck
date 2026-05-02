import Foundation

/// Picks the active SessionTransport implementation.
///
/// Hierarchy (host):
///   - Mock-Override (DEBUG only)                → MockSessionTransport
///   - allowWebJoin && WebSocket configured      → Composite(Multipeer + WebSocket)
///                              + Multipeer
///   - else (default)                            → MultipeerSessionTransport
///
/// All children of a Composite share **one** `localParticipantID` so that the
/// `senderId` baked into wire envelopes is stable regardless of which leg
/// the message took.
@MainActor
enum SessionManager {
    static let mockDefaultsKey = "useMockTransport"

    static var isMockPreferred: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: mockDefaultsKey)
        #else
        return false
        #endif
    }

    static func setMockPreferred(_ on: Bool) {
        #if DEBUG
        UserDefaults.standard.set(on, forKey: mockDefaultsKey)
        #endif
    }

    /// Web-Join is always available — Firebase RTDB needs no server URL.
    static var isWebJoinAvailable: Bool { true }

    static func makeHostTransport(displayName: String,
                                  allowWebJoin: Bool = false,
                                  enableMultipeer: Bool = true) -> SessionTransport {
        if isMockPreferred {
            return MockSessionTransport(role: .host, displayName: displayName)
        }

        let sharedID = UUID().uuidString
        var children: [SessionTransport] = []

        if enableMultipeer {
            children.append(MultipeerSessionTransport(
                role: .host, displayName: displayName, localParticipantID: sharedID
            ))
        }
        if allowWebJoin {
            children.append(FirebaseRTDBTransport(
                role: .host,
                displayName: displayName,
                localParticipantID: sharedID
            ))
        }

        if children.isEmpty {
            return MultipeerSessionTransport(
                role: .host, displayName: displayName, localParticipantID: sharedID
            )
        }
        if children.count == 1 { return children[0] }
        return CompositeSessionTransport(role: .host, children: children)
    }

    static func makeViewerTransport(displayName: String) -> SessionTransport {
        if isMockPreferred {
            return MockSessionTransport(role: .viewer, displayName: displayName)
        }
        // Mirror the host's composite setup: try Multipeer (same Wi-Fi) AND
        // Firebase (works across networks / cellular). Whichever path the host
        // uses delivers the events, which fixes "preview frames never arrive"
        // when the host has allowWebJoin on but the two phones aren't on the
        // same local network.
        let sharedID = UUID().uuidString
        let multi = MultipeerSessionTransport(
            role: .viewer, displayName: displayName, localParticipantID: sharedID
        )
        let fb = FirebaseRTDBTransport(
            role: .viewer, displayName: displayName, localParticipantID: sharedID
        )
        return CompositeSessionTransport(role: .viewer, children: [multi, fb])
    }
}
