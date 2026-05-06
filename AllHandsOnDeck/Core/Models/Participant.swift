import Foundation

/// A connected participant — host or viewer.
struct Participant: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var displayName: String
    var role: SessionRole
    var joinedAt: Date
    var isReady: Bool
    var connectionType: ConnectionType

    init(
        id: String = UUID().uuidString,
        displayName: String,
        role: SessionRole,
        joinedAt: Date = Date(),
        isReady: Bool = false,
        connectionType: ConnectionType = .mock
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.joinedAt = joinedAt
        self.isReady = isReady
        self.connectionType = connectionType
    }
}
