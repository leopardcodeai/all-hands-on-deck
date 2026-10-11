import Foundation
import Combine

/// Transport-level connection lifecycle. View models bind to this so the UI
/// can show "verbinde / verbunden / nicht gefunden / Verbindung verloren".
enum TransportConnectionStatus: Equatable, Sendable {
    case idle
    case advertising
    case browsing
    case connecting
    case connected
    case disconnected
    case notFound
    case failed(String)
}

/// Abstraction over the wire — Multipeer, WebRTC/WebSocket, or in-memory mock all
/// conform. Both host and viewer talk to the rest of the app through this protocol.
@MainActor
protocol SessionTransport: AnyObject {
    var role: SessionRole { get }
    var localParticipantID: String { get }
    var events: AnyPublisher<SessionEvent, Never> { get }
    var connectionStatus: AnyPublisher<TransportConnectionStatus, Never> { get }

    func start(session: PhotoSession) async throws
    func stop()
    func send(_ event: SessionEvent) async
}
