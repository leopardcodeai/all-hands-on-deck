import Foundation

/// Picks the active SessionTransport implementation.
///
/// Hierarchy (host):
///   - Mock-Override (DEBUG only)                → MockSessionTransport
///   - allowWebJoin && Supabase configured       → Composite(Multipeer + Supabase)
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

    static var isWebJoinAvailable: Bool { SupabaseSessionTransport.isConfigured }

    static func makeHostTransport(displayName: String,
                                  allowWebJoin: Bool = false,
                                  enableMultipeer: Bool = true) -> SessionTransport {
        let sharedID = UUID().uuidString

        if isMockPreferred {
            return MockSessionTransport(role: .host, displayName: displayName)
        }

        var children: [SessionTransport] = []

        if enableMultipeer {
            children.append(MultipeerSessionTransport(
                role: .host, displayName: displayName, localParticipantID: sharedID
            ))
        }
        if allowWebJoin && SupabaseSessionTransport.isConfigured {
            children.append(SupabaseSessionTransport(
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
        let sharedID = UUID().uuidString

        if isMockPreferred { return MockSessionTransport(role: .viewer, displayName: displayName) }

        // Mirror the host's composite setup: try Multipeer (same Wi-Fi) AND
        // Supabase (works across networks / cellular). Whichever path the host
        // uses delivers the events, which fixes "preview frames never arrive"
        // when the host has allowWebJoin on but the two phones aren't on the
        // same local network.
        let multi = MultipeerSessionTransport(
            role: .viewer, displayName: displayName, localParticipantID: sharedID
        )
        guard SupabaseSessionTransport.isConfigured else { return multi }
        let supabase = SupabaseSessionTransport(
            role: .viewer, displayName: displayName, localParticipantID: sharedID
        )
        return CompositeSessionTransport(role: .viewer, children: [multi, supabase])
    }
}
