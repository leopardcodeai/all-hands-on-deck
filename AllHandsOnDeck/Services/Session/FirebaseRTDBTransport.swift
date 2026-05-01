import Foundation
import Combine

/// `SessionTransport` backed by Firebase Realtime Database REST API + SSE.
/// No Firebase SDK required — pure URLSession. Replaces WebSocketSessionTransport
/// when web-join is enabled. Frames go to `currentFrame` (overwrite, no history),
/// all other events to `messages/` (push, append-only). SSE streams inbound events.
@MainActor
final class FirebaseRTDBTransport: NSObject, SessionTransport {

    // MARK: - Config

    static let databaseURL = "https://all-hands-on-deck-ae29e-default-rtdb.firebaseio.com"
    static var isConfigured: Bool { true }

    // MARK: - SessionTransport

    let role: SessionRole
    let localParticipantID: String

    private let displayName: String
    private var photoSession: PhotoSession?

    private let eventsSubject = PassthroughSubject<SessionEvent, Never>()
    var events: AnyPublisher<SessionEvent, Never> { eventsSubject.eraseToAnyPublisher() }

    private let statusSubject = CurrentValueSubject<TransportConnectionStatus, Never>(.idle)
    var connectionStatus: AnyPublisher<TransportConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    private var streamTask: URLSessionDataTask?
    private var sseURLSession: URLSession?
    private var sseDelegate: SSEStreamDelegate?
    private var seenMessageKeys = Set<String>()
    private var currentSSEEventType = ""

    init(role: SessionRole, displayName: String, localParticipantID: String = UUID().uuidString) {
        self.role = role
        self.displayName = displayName
        self.localParticipantID = localParticipantID
    }

    // MARK: - Lifecycle

    func start(session: PhotoSession) async throws {
        photoSession = session
        statusSubject.send(.connecting)

        if role == .host {
            await writeSessionMeta(session: session)
        } else {
            let me = Participant(
                id: localParticipantID,
                displayName: displayName,
                role: .viewer,
                connectionType: .web
            )
            await send(.participantJoined(me))
        }

        statusSubject.send(.connected)
        startSSEStream(sessionId: session.id)
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        sseURLSession?.invalidateAndCancel()
        sseURLSession = nil
        statusSubject.send(.idle)

        if role == .host, let sid = photoSession?.id {
            Task { await self.deleteSession(sessionId: sid) }
        }
    }

    // MARK: - Send

    func send(_ event: SessionEvent) async {
        guard let sessionId = photoSession?.id else { return }

        // Frames overwrite a single node for low-latency delivery.
        if case .previewFrame = event {
            await writeFrame(event: event, sessionId: sessionId)
            return
        }
        let envelope = SessionWireMessage(
            sessionId: sessionId,
            senderId: localParticipantID,
            createdAt: Date(),
            event: event
        )
        await pushMessage(envelope, sessionId: sessionId)
    }

    // MARK: - Firebase REST writes

    private func writeSessionMeta(session: PhotoSession) async {
        let meta: [String: Any] = [
            "hostId": localParticipantID,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        await put(path: "sessions/\(session.id)/meta", body: meta)
    }

    private func writeFrame(event: SessionEvent, sessionId: String) async {
        guard let data = try? SessionWireMessage(
            sessionId: sessionId, senderId: localParticipantID,
            createdAt: Date(), event: event
        ).encoded() else { return }
        await putData(path: "sessions/\(sessionId)/currentFrame", data: data)
    }

    private func pushMessage(_ envelope: SessionWireMessage, sessionId: String) async {
        guard let data = try? envelope.encoded() else { return }
        await postData(path: "sessions/\(sessionId)/messages", data: data)
    }

    private func deleteSession(sessionId: String) async {
        guard let url = URL(string: "\(Self.databaseURL)/sessions/\(sessionId).json") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: - SSE streaming

    private func startSSEStream(sessionId: String) {
        // Host watches incoming viewer messages; viewers watch everything.
        let path = role == .host
            ? "sessions/\(sessionId)/messages"
            : "sessions/\(sessionId)"

        guard let url = URL(string: "\(Self.databaseURL)/\(path).json") else { return }
        var req = URLRequest(url: url)
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        req.timeoutInterval = 3600

        let delegate = SSEStreamDelegate { [weak self] eventType, json in
            Task { @MainActor [weak self] in
                self?.handleSSEPayload(eventType: eventType, json: json)
            }
        }
        sseDelegate = delegate
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        sseURLSession = session
        streamTask = session.dataTask(with: req)
        streamTask?.resume()
    }

    private func handleSSEPayload(eventType: String, json: String) {
        guard eventType == "put" || eventType == "patch" else { return }
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let path = root["path"] as? String ?? "/"
        let payload = root["data"]

        if role == .host {
            handleHostUpdate(path: path, payload: payload)
        } else {
            handleViewerUpdate(path: path, payload: payload)
        }
    }

    // Host watches sessions/{id}/messages — Firebase sends incremental puts with path = "/-KEY"
    private func handleHostUpdate(path: String, payload: Any?) {
        if path == "/" {
            // Initial snapshot: payload is the full messages dict (or null)
            guard let msgs = payload as? [String: Any] else { return }
            processMessageDict(msgs)
        } else {
            // Incremental: path is "/-NABCDE", payload is the message envelope
            let key = String(path.dropFirst()) // strip leading "/"
            guard !seenMessageKeys.contains(key),
                  let dict = payload as? [String: Any] else { return }
            insertSeen(key)
            decodeAndEmit(dict: dict)
        }
    }

    // Viewer watches sessions/{id} — updates arrive at various sub-paths
    private func handleViewerUpdate(path: String, payload: Any?) {
        if path == "/" {
            guard let top = payload as? [String: Any] else { return }
            if let msgs = top["messages"] as? [String: Any] { processMessageDict(msgs) }
            if let frame = top["currentFrame"] as? [String: Any] { decodeAndEmit(dict: frame) }
        } else if path == "/currentFrame" {
            if let frame = payload as? [String: Any] { decodeAndEmit(dict: frame) }
        } else if path.hasPrefix("/messages/") {
            let key = String(path.dropFirst("/messages/".count))
            guard !seenMessageKeys.contains(key),
                  let dict = payload as? [String: Any] else { return }
            insertSeen(key)
            decodeAndEmit(dict: dict)
        } else if path == "/messages" {
            if let msgs = payload as? [String: Any] { processMessageDict(msgs) }
        }
    }

    private func processMessageDict(_ msgs: [String: Any]) {
        for (key, value) in msgs {
            guard !seenMessageKeys.contains(key), let dict = value as? [String: Any] else { continue }
            insertSeen(key)
            decodeAndEmit(dict: dict)
        }
    }

    private func insertSeen(_ key: String) {
        seenMessageKeys.insert(key)
        if seenMessageKeys.count > 200 {
            seenMessageKeys.removeFirst()
        }
    }

    private func decodeAndEmit(dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let envelope = try? SessionWireMessage.decode(data),
              envelope.senderId != localParticipantID else { return }
        eventsSubject.send(envelope.event)
    }

    // MARK: - HTTP helpers

    private func put(path: String, body: [String: Any]) async {
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        await putData(path: path, data: data)
    }

    private func putData(path: String, data: Data) async {
        guard let url = URL(string: "\(Self.databaseURL)/\(path).json") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try? await URLSession.shared.data(for: req)
    }

    private func post(path: String, body: [String: Any]) async {
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        await postData(path: path, data: data)
    }

    private func postData(path: String, data: Data) async {
        guard let url = URL(string: "\(Self.databaseURL)/\(path).json") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try? await URLSession.shared.data(for: req)
    }
}

// MARK: - SSE delegate

private final class SSEStreamDelegate: NSObject, URLSessionDataDelegate {
    private let onEvent: (String, String) -> Void
    private var buffer = ""
    private var pendingEventType = ""

    init(onEvent: @escaping (String, String) -> Void) {
        self.onEvent = onEvent
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text
        var lines = buffer.components(separatedBy: "\n")
        buffer = lines.removeLast()
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("event: ") {
                pendingEventType = String(trimmed.dropFirst(7))
            } else if trimmed.hasPrefix("data: ") {
                let json = String(trimmed.dropFirst(6))
                onEvent(pendingEventType, json)
            }
        }
    }
}
