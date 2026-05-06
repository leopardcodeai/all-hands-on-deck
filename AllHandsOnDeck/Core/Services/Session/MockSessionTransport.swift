import Foundation
import Combine

/// In-memory transport used for development and previews.
///
/// A single shared `MockBroker` connects all `MockSessionTransport` instances
/// in the same process by `sessionId`, so a host transport and viewer
/// transport can talk to each other inside the simulator.
@MainActor
final class MockSessionTransport: SessionTransport {
    let role: SessionRole
    let localParticipantID: String
    private let displayName: String

    private let subject = PassthroughSubject<SessionEvent, Never>()
    var events: AnyPublisher<SessionEvent, Never> { subject.eraseToAnyPublisher() }

    private let statusSubject = CurrentValueSubject<TransportConnectionStatus, Never>(.idle)
    var connectionStatus: AnyPublisher<TransportConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    private var sessionID: String?
    private weak var broker: MockBroker?

    init(role: SessionRole, displayName: String) {
        self.role = role
        self.localParticipantID = UUID().uuidString
        self.displayName = displayName
    }

    func start(session: PhotoSession) async throws {
        self.sessionID = session.id
        let broker = MockBroker.shared
        self.broker = broker
        broker.register(self, for: session.id)

        statusSubject.send(.connected)

        if role == .viewer {
            let me = Participant(
                id: localParticipantID,
                displayName: displayName,
                role: .viewer,
                connectionType: .mock
            )
            await send(.participantJoined(me))
        }
    }

    func stop() {
        if let id = sessionID {
            broker?.unregister(self, for: id)
        }
        sessionID = nil
        statusSubject.send(.idle)
    }

    func send(_ event: SessionEvent) async {
        guard let id = sessionID else { return }
        broker?.dispatch(event, from: self, sessionID: id)
    }

    fileprivate func receive(_ event: SessionEvent) {
        subject.send(event)
    }
}

// MARK: - Broker

/// Process-wide pub/sub fabric for mock transports.
@MainActor
final class MockBroker {
    @MainActor static let shared = MockBroker()
    private init() {}

    private var rooms: [String: [WeakRef]] = [:]

    private final class WeakRef {
        weak var transport: MockSessionTransport?
        init(_ t: MockSessionTransport) { transport = t }
    }

    func register(_ transport: MockSessionTransport, for sessionID: String) {
        var refs = rooms[sessionID] ?? []
        refs.removeAll { $0.transport == nil }
        refs.append(WeakRef(transport))
        rooms[sessionID] = refs
    }

    func unregister(_ transport: MockSessionTransport, for sessionID: String) {
        guard var refs = rooms[sessionID] else { return }
        refs.removeAll { $0.transport === transport || $0.transport == nil }
        rooms[sessionID] = refs.isEmpty ? nil : refs
    }

    func dispatch(_ event: SessionEvent, from sender: MockSessionTransport, sessionID: String) {
        guard let refs = rooms[sessionID] else { return }
        for ref in refs {
            guard let peer = ref.transport, peer !== sender else { continue }
            peer.receive(event)
        }
    }
}
