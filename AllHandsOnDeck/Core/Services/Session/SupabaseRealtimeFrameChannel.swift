import Foundation

/// Wire-format helpers for preview-frame broadcasts over Supabase Realtime.
///
/// Frames are too chatty for `session_events` (INSERT churn at ~3fps), so the
/// host pushes them through Realtime Broadcast instead: REST POST on the send
/// side, Phoenix websocket on the receive side. This namespace owns both wire
/// shapes so the transport and the channel client stay in sync — and so the
/// encoding/decoding is unit-testable without any networking.
enum SupabaseFrameBroadcast {
    /// Broadcast event name carried inside the Phoenix envelope.
    static let eventName = "preview_frame"

    /// Topic for a session's frame stream. `sessionID` is the Supabase
    /// `sessions.id` UUID, NOT the 6-character join code.
    static func topic(forSessionID sessionID: String) -> String {
        "session-frames:\(sessionID)"
    }

    /// Payload of one frame, as it travels inside the broadcast message.
    struct FramePayload: Codable {
        let jpeg: String        // base64-encoded JPEG bytes
        let capturedAt: String  // ISO8601
        let senderId: String
    }

    /// One message in the REST broadcast body.
    struct Message: Codable {
        let topic: String
        let event: String
        let payload: FramePayload
    }

    /// Body for `POST {SUPABASE_URL}/realtime/v1/api/broadcast`.
    struct RequestBody: Codable {
        let messages: [Message]
    }

    /// Builds the encoded REST body for one frame broadcast.
    static func requestBody(
        sessionID: String,
        jpeg: Data,
        capturedAt: Date,
        senderId: String
    ) throws -> Data {
        let body = RequestBody(messages: [
            Message(
                topic: topic(forSessionID: sessionID),
                event: eventName,
                payload: FramePayload(
                    jpeg: jpeg.base64EncodedString(),
                    capturedAt: isoFormatter.string(from: capturedAt),
                    senderId: senderId
                )
            )
        ])
        return try encoder.encode(body)
    }

    // MARK: - Incoming Phoenix messages

    /// A decoded preview frame received from the websocket.
    struct IncomingFrame {
        let jpeg: Data
        let capturedAt: Date
        let senderId: String
    }

    /// Outer Phoenix envelope. Broadcasts arrive as
    /// `{"event":"broadcast","payload":{"event":"preview_frame","payload":{...}}}` —
    /// the actual frame payload is nested one level down.
    private struct PhoenixEnvelope: Decodable {
        let event: String
        let payload: BroadcastPayload?

        struct BroadcastPayload: Decodable {
            let event: String?
            let payload: FramePayload?
        }
    }

    /// Decodes a raw websocket message into a frame, or `nil` if the message
    /// is anything else (phx_reply, presence, heartbeat replies, …).
    static func decodeIncomingFrame(_ data: Data) -> IncomingFrame? {
        guard let envelope = try? decoder.decode(PhoenixEnvelope.self, from: data),
              envelope.event == "broadcast",
              envelope.payload?.event == eventName,
              let frame = envelope.payload?.payload,
              let jpeg = Data(base64Encoded: frame.jpeg),
              let capturedAt = parseISO8601(frame.capturedAt)
        else { return nil }
        return IncomingFrame(jpeg: jpeg, capturedAt: capturedAt, senderId: frame.senderId)
    }

    /// Parses ISO8601 with or without fractional seconds (the web client
    /// emits fractional, iOS does not).
    static func parseISO8601(_ string: String) -> Date? {
        isoFormatter.date(from: string) ?? isoFractionalFormatter.date(from: string)
    }

    // MARK: - Shared coders

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    private static let isoFormatter = ISO8601DateFormatter()

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

/// Minimal Phoenix-channel client that subscribes to a session's
/// `session-frames:{uuid}` Realtime topic and surfaces decoded preview
/// frames via a callback. Used by the viewer only — the host sends frames
/// via REST broadcast and never needs a receive path.
///
/// Connection lifecycle: connect → phx_join → heartbeat every 25s; on any
/// read error we tear down and retry after a short delay until `stop()`.
@MainActor
final class SupabaseRealtimeFrameChannel {
    typealias FrameHandler = (_ jpeg: Data, _ capturedAt: Date, _ senderId: String) -> Void

    private let supabaseURLString: String
    private let anonKey: String
    private let sessionID: String
    private let localSenderID: String
    private let onFrame: FrameHandler

    private var task: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var heartbeatRef = 1
    private var isStopped = false

    private lazy var urlSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg, delegate: nil, delegateQueue: nil)
    }()

    private static let heartbeatInterval: UInt64 = 25_000_000_000  // 25s
    private static let reconnectDelay: UInt64 = 2_000_000_000      // 2s

    init(
        supabaseURLString: String,
        anonKey: String,
        sessionID: String,
        localSenderID: String,
        onFrame: @escaping FrameHandler
    ) {
        self.supabaseURLString = supabaseURLString
        self.anonKey = anonKey
        self.sessionID = sessionID
        self.localSenderID = localSenderID
        self.onFrame = onFrame
    }

    // MARK: - Lifecycle

    func start() {
        isStopped = false
        connect()
    }

    func stop() {
        isStopped = true
        heartbeatTask?.cancel()
        heartbeatTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    // MARK: - Connection

    private var websocketURL: URL? {
        guard var components = URLComponents(string: supabaseURLString) else { return nil }
        components.scheme = "wss"
        components.path = "/realtime/v1/websocket"
        components.queryItems = [
            URLQueryItem(name: "apikey", value: anonKey),
            URLQueryItem(name: "vsn", value: "1.0.0")
        ]
        return components.url
    }

    private func connect() {
        guard !isStopped, let url = websocketURL else { return }
        let task = urlSession.webSocketTask(with: url)
        self.task = task
        task.resume()
        join(task: task)
        readLoop(task: task)
        startHeartbeat(task: task)
    }

    /// Joins the Realtime topic. `broadcast.self: false` so our own frames
    /// are not echoed back (the senderId check below is belt-and-braces).
    private func join(task: URLSessionWebSocketTask) {
        let joinMessage: [String: Any] = [
            "topic": "realtime:\(SupabaseFrameBroadcast.topic(forSessionID: sessionID))",
            "event": "phx_join",
            "payload": [
                "config": [
                    "broadcast": ["self": false],
                    "presence": ["key": ""],
                    "postgres_changes": [[String: Any]]()
                ]
            ],
            "ref": "1"
        ]
        sendJSON(joinMessage, over: task)
    }

    private func startHeartbeat(task: URLSessionWebSocketTask) {
        heartbeatTask?.cancel()
        heartbeatRef = 1
        heartbeatTask = Task { [weak self, weak task] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.heartbeatInterval)
                guard !Task.isCancelled, let self, let task else { return }
                self.heartbeatRef += 1
                self.sendJSON([
                    "topic": "phoenix",
                    "event": "heartbeat",
                    "payload": [String: Any](),
                    "ref": "\(self.heartbeatRef)"
                ], over: task)
            }
        }
    }

    private func sendJSON(_ object: [String: Any], over task: URLSessionWebSocketTask) {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return }
        Task {
            do {
                try await task.send(.string(text))
            } catch {
                AppLog.transport.error("frame channel send failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Read loop

    private func readLoop(task: URLSessionWebSocketTask) {
        Task { [weak self, weak task] in
            guard let task else { return }
            do {
                let message = try await task.receive()
                self?.handle(message)
                self?.readLoop(task: task)
            } catch {
                self?.handleDisconnect(of: task)
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .data(let d): data = d
        case .string(let s): data = Data(s.utf8)
        @unknown default: return
        }

        guard let frame = SupabaseFrameBroadcast.decodeIncomingFrame(data),
              frame.senderId != localSenderID else { return }
        onFrame(frame.jpeg, frame.capturedAt, frame.senderId)
    }

    // MARK: - Reconnect

    private func handleDisconnect(of failedTask: URLSessionWebSocketTask) {
        // Ignore errors from tasks we already replaced or tore down.
        guard !isStopped, failedTask === task else { return }
        heartbeatTask?.cancel()
        heartbeatTask = nil
        task = nil
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.reconnectDelay)
            guard let self, !self.isStopped, self.task == nil else { return }
            AppLog.transport.info("frame channel reconnecting")
            self.connect()
        }
    }
}
