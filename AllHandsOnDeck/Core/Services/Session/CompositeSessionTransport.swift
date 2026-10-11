import Foundation
import Combine

/// Sends every event to every wrapped transport and merges their inbound
/// streams into a single publisher. Used on the host when Web-Join is
/// enabled — simultaneously runs Multipeer (for Nearby/QR native joiners)
/// and WebSocket (for browser viewers).
///
/// Connection status surfaces the most-permissive state across children:
/// - `.connected` if any child is connected
/// - else `.advertising` / `.connecting` if any child is in those states
/// - else `.idle`
@MainActor
final class CompositeSessionTransport: SessionTransport {
    let role: SessionRole
    let localParticipantID: String

    private let children: [SessionTransport]

    private let eventsSubject = PassthroughSubject<SessionEvent, Never>()
    var events: AnyPublisher<SessionEvent, Never> { eventsSubject.eraseToAnyPublisher() }

    private let statusSubject = CurrentValueSubject<TransportConnectionStatus, Never>(.idle)
    var connectionStatus: AnyPublisher<TransportConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    private var subs: Set<AnyCancellable> = []
    private var lastChildStatuses: [TransportConnectionStatus]

    init(role: SessionRole, children: [SessionTransport]) {
        precondition(!children.isEmpty, "CompositeSessionTransport requires at least one child.")
        self.role = role
        // The composite gets its own ID; child transports each have their own
        // (used inside the Multipeer/WebSocket protocols), but external
        // consumers see only this one.
        self.localParticipantID = children.first!.localParticipantID
        self.children = children
        self.lastChildStatuses = Array(repeating: .idle, count: children.count)

        for (idx, child) in children.enumerated() {
            child.events
                .sink { [weak self] e in self?.eventsSubject.send(e) }
                .store(in: &subs)
            child.connectionStatus
                .sink { [weak self] s in
                    self?.lastChildStatuses[idx] = s
                    self?.recomputeStatus()
                }
                .store(in: &subs)
        }
    }

    func start(session: PhotoSession) async throws {
        for child in children {
            try await child.start(session: session)
        }
    }

    func stop() {
        for child in children { child.stop() }
    }

    func send(_ event: SessionEvent) async {
        await withTaskGroup(of: Void.self) { group in
            for child in children {
                group.addTask { await child.send(event) }
            }
        }
    }

    private func recomputeStatus() {
        // Pick the most "alive" status across children.
        let order: [TransportConnectionStatus] = [.connected, .advertising, .browsing, .connecting, .disconnected, .notFound, .idle]
        let scored: TransportConnectionStatus = order.first { candidate in
            lastChildStatuses.contains { match($0, candidate) }
        } ?? .idle
        if statusSubject.value != scored {
            statusSubject.send(scored)
        }
    }

    private func match(_ a: TransportConnectionStatus, _ b: TransportConnectionStatus) -> Bool {
        switch (a, b) {
        case (.idle, .idle), (.advertising, .advertising), (.browsing, .browsing),
             (.connecting, .connecting), (.connected, .connected),
             (.disconnected, .disconnected), (.notFound, .notFound):
            return true
        case (.failed, .failed): return true
        default: return false
        }
    }
}
