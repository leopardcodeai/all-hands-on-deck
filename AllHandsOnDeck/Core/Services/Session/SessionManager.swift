import Foundation

/// Picks the active SessionTransport implementation.
///
/// Hierarchy (host):
///   - allowWebJoin && Supabase configured       → Composite(Multipeer + Supabase)
///   - else (default)                            → MultipeerSessionTransport
///
/// All children of a Composite share **one** `localParticipantID` so that the
/// `senderId` baked into wire envelopes is stable regardless of which leg
/// the message took.
@MainActor
enum SessionManager {
    static var isWebJoinAvailable: Bool { SupabaseSessionTransport.isConfigured }

    static func makeHostTransport(displayName: String,
                                  allowWebJoin: Bool = false,
                                  enableMultipeer: Bool = true) -> SessionTransport {
        let sharedID = UUID().uuidString

        if ProcessInfo.processInfo.arguments.contains("-useMockTransport") {
            return MockSessionTransport(role: .host, localParticipantID: sharedID)
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

        if ProcessInfo.processInfo.arguments.contains("-useMockTransport") {
            return MockSessionTransport(role: .viewer, localParticipantID: sharedID)
        }

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
