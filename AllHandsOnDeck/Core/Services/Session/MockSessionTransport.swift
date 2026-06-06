import Foundation
import Combine

/// Mock session transport used for UI testing.
/// Conforms to SessionTransport and simulates a connected state.
final class MockSessionTransport: SessionTransport {
    let role: SessionRole
    let localParticipantID: String

    private let eventsSubject = PassthroughSubject<SessionEvent, Never>()
    var events: AnyPublisher<SessionEvent, Never> { eventsSubject.eraseToAnyPublisher() }

    private let statusSubject = CurrentValueSubject<TransportConnectionStatus, Never>(.idle)
    var connectionStatus: AnyPublisher<TransportConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    private var photoSession: PhotoSession?

    init(role: SessionRole, localParticipantID: String = UUID().uuidString) {
        self.role = role
        self.localParticipantID = localParticipantID
    }

    func start(session: PhotoSession) async throws {
        photoSession = session
        statusSubject.send(.connecting)
        try? await Task.sleep(nanoseconds: 100_000_000)
        statusSubject.send(.connected)
        
        if role == .viewer {
            // Simulate host sending initial metadata and joining
            let mockSession = PhotoSession(
                id: session.id,
                hostName: "Mock Captain",
                ttlMinutes: 60,
                timerDuration: 10,
                triggerPermission: .everyoneCanStartTimer,
                isDiscoverableNearby: true,
                allowWebJoin: true,
                allowFinalPhotoDownload: true,
                participants: [
                    Participant(id: "mock-host-id", displayName: "Mock Captain", role: .host, connectionType: .mock),
                    Participant(id: localParticipantID, displayName: "Viewer", role: .viewer, connectionType: .mock)
                ]
            )
            eventsSubject.send(.sessionMetadata(mockSession))
        }
    }

    func stop() {
        statusSubject.send(.idle)
    }

    func send(_ event: SessionEvent) async {
        // Echo back local events for testing purposes
        eventsSubject.send(event)
    }
}
