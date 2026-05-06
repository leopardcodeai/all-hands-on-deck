import Foundation
import Combine

/// `SessionTransport` that talks to the Node signaling/relay server over a
/// single WebSocket. Uses the same `SessionWireMessage` envelope as Multipeer,
/// so events flow through the rest of the app unchanged.
///
/// Connect URL: `wss://<host>/ws?session=<id>&role=host|viewer&pid=<participantID>`
@MainActor
final class WebSocketSessionTransport: NSObject, SessionTransport {
    /// Returns the configured signaling server URL, or `nil` if the user
    /// hasn't set `webSocketServerURL` in UserDefaults / launch args yet.
    /// `nil` means "Web-Join is not really wired up" — Composite skips us.
    static var configuredServerURL: URL? {
        guard let s = UserDefaults.standard.string(forKey: "webSocketServerURL"),
              !s.isEmpty,
              let u = URL(string: s) else { return nil }
        return u
    }
    static var isConfigured: Bool { configuredServerURL != nil }

    let role: SessionRole
    let localParticipantID: String

    private let displayName: String
    private let serverURL: URL

    private let eventsSubject = PassthroughSubject<SessionEvent, Never>()
    var events: AnyPublisher<SessionEvent, Never> { eventsSubject.eraseToAnyPublisher() }

    private let statusSubject = CurrentValueSubject<TransportConnectionStatus, Never>(.idle)
    var connectionStatus: AnyPublisher<TransportConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    private var photoSession: PhotoSession?
    private var task: URLSessionWebSocketTask?
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg, delegate: nil, delegateQueue: nil)
    }()

    init(role: SessionRole,
         displayName: String,
         localParticipantID: String = UUID().uuidString,
         serverURL: URL) {
        self.role = role
        self.localParticipantID = localParticipantID
        self.displayName = displayName
        self.serverURL = serverURL
    }

    // MARK: - Lifecycle

    func start(session: PhotoSession) async throws {
        photoSession = session

        var comps = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
        if comps.path.isEmpty || comps.path == "/" { comps.path = "/ws" }
        comps.queryItems = [
            URLQueryItem(name: "session", value: session.id),
            URLQueryItem(name: "role", value: role == .host ? "host" : "viewer"),
            URLQueryItem(name: "pid", value: localParticipantID)
        ]
        guard let url = comps.url else {
            throw NSError(domain: "WebSocket", code: -1)
        }

        statusSubject.send(.connecting)
        let task = self.session.webSocketTask(with: url)
        self.task = task
        task.resume()
        readLoop(task: task)

        // Viewer announces itself with a participantJoined.
        if role == .viewer {
            let me = Participant(
                id: localParticipantID,
                displayName: displayName,
                role: .viewer,
                connectionType: .web
            )
            await send(.participantJoined(me))
        }
    }

    func stop() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        statusSubject.send(.idle)
    }

    // MARK: - Send

    func send(_ event: SessionEvent) async {
        guard let task, let sessionId = photoSession?.id else { return }
        let envelope = SessionWireMessage(
            sessionId: sessionId,
            senderId: localParticipantID,
            createdAt: Date(),
            event: event
        )
        do {
            let data = try envelope.encoded()
            // We send everything as a text message because the web client and
            // the server's relay logic are JSON-only. Frames are base64 inside
            // the JSON (handled by SessionEvent's Codable).
            guard let str = String(data: data, encoding: .utf8) else { return }
            try await task.send(.string(str))
        } catch {
            AppLog.transport.error("ws send failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Read loop

    private func readLoop(task: URLSessionWebSocketTask) {
        Task { [weak self, weak task] in
            guard let task else { return }
            do {
                let message = try await task.receive()
                await self?.handle(message)
                self?.readLoop(task: task)
            } catch {
                await MainActor.run {
                    if self?.statusSubject.value != .idle {
                        self?.statusSubject.send(.disconnected)
                    }
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) async {
        let data: Data
        switch message {
        case .data(let d): data = d
        case .string(let s): data = Data(s.utf8)
        @unknown default: return
        }

        // First, try parsing as a server-control envelope.
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let kind = obj["kind"] as? String {
            switch kind {
            case "joined":
                statusSubject.send(.connected)
            case "viewerJoined":
                if let pid = obj["participantId"] as? String {
                    // Synthesize a participantJoined for the host; the real Participant
                    // payload arrives next from the viewer itself, but this gives the
                    // host an immediate "someone is here" signal.
                    eventsSubject.send(.participantJoined(Participant(
                        id: pid,
                        displayName: "Web Viewer",
                        role: .viewer,
                        connectionType: .web
                    )))
                }
            case "viewerLeft":
                if let pid = obj["participantId"] as? String {
                    eventsSubject.send(.participantLeft(participantID: pid))
                }
            case "error":
                statusSubject.send(.failed(obj["reason"] as? String ?? "error"))
            default:
                break
            }
            return
        }

        // Otherwise, decode as a SessionWireMessage envelope.
        do {
            let envelope = try SessionWireMessage.decode(data)
            eventsSubject.send(envelope.event)
        } catch {
            AppLog.transport.error("ws decode failed: \(error.localizedDescription)")
        }
    }
}
