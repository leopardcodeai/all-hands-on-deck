import Foundation

/// Whether a participant is the camera host or a remote viewer.
enum SessionRole: String, Codable, Hashable, Sendable {
    case host
    case viewer
}
