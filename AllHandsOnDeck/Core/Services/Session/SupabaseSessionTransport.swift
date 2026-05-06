import Foundation
import Combine

/// Supabase-backed session transport using PostgREST writes plus lightweight
/// event polling on iOS. The web client subscribes to the same `session_events`
/// table through Supabase Realtime, so both surfaces share one wire envelope.
@MainActor
final class SupabaseSessionTransport: SessionTransport {
    // MARK: - Config

    private static var supabaseURLString: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
    }

    private static var anonKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }

    static var isConfigured: Bool {
        !supabaseURLString.isEmpty && !anonKey.isEmpty
    }

    // MARK: - SessionTransport

    let role: SessionRole
    let localParticipantID: String

    private let displayName: String
    private var photoSession: PhotoSession?
    private var supabaseSessionID: String?
    private var supabaseParticipantID: String?
    private var lastEventCreatedAt: String?
    private var seenEventIDs = Set<String>()
    private var pollingTask: Task<Void, Never>?

    private let eventsSubject = PassthroughSubject<SessionEvent, Never>()
    var events: AnyPublisher<SessionEvent, Never> { eventsSubject.eraseToAnyPublisher() }

    private let statusSubject = CurrentValueSubject<TransportConnectionStatus, Never>(.idle)
    var connectionStatus: AnyPublisher<TransportConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    init(role: SessionRole, displayName: String, localParticipantID: String = UUID().uuidString) {
        self.role = role
        self.displayName = displayName
        self.localParticipantID = localParticipantID
    }

    func start(session: PhotoSession) async throws {
        guard Self.isConfigured else {
            statusSubject.send(.failed("Supabase is not configured"))
            return
        }

        photoSession = session
        statusSubject.send(.connecting)

        if role == .host {
            try await createSession(session)
            try await createParticipant(role: .host, connectionType: .web)
            await send(.sessionMetadata(session))
        } else {
            try await loadSession(code: session.id)
            try await createParticipant(role: .viewer, connectionType: .web)
            let me = Participant(
                id: localParticipantID,
                displayName: displayName,
                role: .viewer,
                connectionType: .web
            )
            await send(.participantJoined(me))
        }

        statusSubject.send(.connected)
        startPolling()
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        statusSubject.send(.idle)
    }

    func send(_ event: SessionEvent) async {
        guard let session = photoSession,
              let supabaseSessionID,
              Self.isConfigured else { return }

        let envelope = SessionWireMessage(
            sessionId: session.id,
            senderId: localParticipantID,
            createdAt: Date(),
            event: event
        )
        let insert = SupabaseEventInsert(
            sessionId: supabaseSessionID,
            senderParticipantId: supabaseParticipantID,
            type: event.transportType,
            payload: envelope,
            clientGeneratedId: UUID().uuidString
        )
        do {
            let _: [SupabaseInsertedID] = try await request(
                path: "session_events",
                queryItems: [URLQueryItem(name: "select", value: "id")],
                method: "POST",
                body: insert,
                preferRepresentation: true,
                response: [SupabaseInsertedID].self
            )
            DebugSessionState.shared.recordSupabaseWrite(success: true)
        } catch {
            DebugSessionState.shared.recordSupabaseWrite(success: false)
        }
    }

    // MARK: - Session bootstrap

    private func createSession(_ session: PhotoSession) async throws {
        let insert = SupabaseSessionInsert(
            code: session.id,
            status: "active",
            expiresAt: session.expiresAt,
            joinTokenExpiresAt: session.joinToken?.expiresAt,
            maxViewers: SessionPolicy.mvp.maxP2PViewers,
            maxDurationMinutes: SessionPolicy.mvp.maxSessionDurationMinutes,
            turnMinutesUsed: 0,
            realtimeMessagesPerMinute: SessionPolicy.mvp.realtimeMessagesPerMinute,
            webViewersFeatureStage: SessionPolicy.mvp.webViewersFeatureStage,
            metadata: session
        )
        let rows = try await request(
            path: "sessions",
            queryItems: [URLQueryItem(name: "select", value: "*")],
            method: "POST",
            body: insert,
            preferRepresentation: true,
            response: [SupabaseSessionRow].self
        )
        guard let row = rows.first else { throw SupabaseTransportError.emptyResponse }
        supabaseSessionID = row.id
    }

    private func loadSession(code: String) async throws {
        let rows = try await request(
            path: "sessions",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "code", value: "eq.\(code)"),
                URLQueryItem(name: "status", value: "eq.active")
            ],
            method: "GET",
            body: Optional<SupabaseSessionInsert>.none,
            preferRepresentation: false,
            response: [SupabaseSessionRow].self
        )
        guard let row = rows.first else {
            statusSubject.send(.notFound)
            throw SupabaseTransportError.emptyResponse
        }
        supabaseSessionID = row.id
    }

    private func createParticipant(role: SessionRole, connectionType: ConnectionType) async throws {
        guard let supabaseSessionID else { throw SupabaseTransportError.missingSession }
        let insert = SupabaseParticipantInsert(
            sessionId: supabaseSessionID,
            anonymousId: localParticipantID,
            displayName: displayName,
            role: role == .host ? "host" : "viewer",
            peerId: localParticipantID,
            livekitIdentity: localParticipantID
        )
        let rows = try await request(
            path: "session_participants",
            queryItems: [URLQueryItem(name: "select", value: "*")],
            method: "POST",
            body: insert,
            preferRepresentation: true,
            response: [SupabaseParticipantRow].self
        )
        guard let row = rows.first else { throw SupabaseTransportError.emptyResponse }
        supabaseParticipantID = row.id
    }

    // MARK: - Polling fallback

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollEvents()
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
        }
    }

    private func pollEvents() async {
        guard let supabaseSessionID else { return }
        DebugSessionState.shared.recordSupabaseMsgsPoll()
        var queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "session_id", value: "eq.\(supabaseSessionID)"),
            URLQueryItem(name: "order", value: "created_at.asc")
        ]
        if let lastEventCreatedAt {
            queryItems.append(URLQueryItem(name: "created_at", value: "gt.\(lastEventCreatedAt)"))
        }

        do {
            let rows = try await request(
                path: "session_events",
                queryItems: queryItems,
                method: "GET",
                body: Optional<SupabaseEventInsert>.none,
                preferRepresentation: false,
                response: [SupabaseEventRow].self
            )
            DebugSessionState.shared.recordSupabaseRead(success: true)
            for row in rows where !seenEventIDs.contains(row.id) {
                seenEventIDs.insert(row.id)
                lastEventCreatedAt = row.createdAt
                guard row.payload.senderId != localParticipantID else { continue }
                eventsSubject.send(row.payload.event)
            }
            if seenEventIDs.count > 300 {
                for id in seenEventIDs.prefix(seenEventIDs.count - 300) {
                    seenEventIDs.remove(id)
                }
            }
        } catch {
            DebugSessionState.shared.recordSupabaseRead(success: false)
        }
    }

    // MARK: - HTTP

    private func request<Body: Encodable, Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        method: String,
        body: Body?,
        preferRepresentation: Bool,
        response: Response.Type
    ) async throws -> Response {
        guard var components = URLComponents(string: "\(Self.supabaseURLString)/rest/v1/\(path)") else {
            throw SupabaseTransportError.invalidURL
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw SupabaseTransportError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if preferRepresentation {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        if let body {
            request.httpBody = try Self.encoder.encode(body)
        }

        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        guard let http = urlResponse as? HTTPURLResponse,
              200..<300 ~= http.statusCode else {
            throw SupabaseTransportError.httpFailure
        }
        return try Self.decoder.decode(Response.self, from: data)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

private enum SupabaseTransportError: Error {
    case invalidURL
    case httpFailure
    case emptyResponse
    case missingSession
}

private struct SupabaseSessionRow: Decodable {
    let id: String
}

private struct SupabaseParticipantRow: Decodable {
    let id: String
}

private struct SupabaseInsertedID: Decodable {
    let id: String
}

private struct SupabaseEventRow: Decodable {
    let id: String
    let payload: SessionWireMessage
    let createdAt: String
}

private struct SupabaseSessionInsert: Encodable {
    let code: String
    let status: String
    let expiresAt: Date
    let joinTokenExpiresAt: Date?
    let maxViewers: Int
    let maxDurationMinutes: Int
    let turnMinutesUsed: Int
    let realtimeMessagesPerMinute: Int
    let webViewersFeatureStage: String
    let metadata: PhotoSession
}

private struct SupabaseParticipantInsert: Encodable {
    let sessionId: String
    let anonymousId: String
    let displayName: String
    let role: String
    let peerId: String
    let livekitIdentity: String
}

private struct SupabaseEventInsert: Encodable {
    let sessionId: String
    let senderParticipantId: String?
    let type: String
    let payload: SessionWireMessage
    let clientGeneratedId: String
}

private extension SessionEvent {
    var transportType: String {
        switch self {
        case .sessionMetadata: return "sessionMetadata"
        case .participantJoined: return "participantJoined"
        case .participantLeft: return "participantLeft"
        case .participantReadyChanged: return "participantReadyChanged"
        case .previewFrame: return "previewFrame"
        case .countdownStarted: return "countdownStarted"
        case .countdownCancelled: return "countdownCancelled"
        case .captureRequested: return "captureRequested"
        case .captureNowRequested: return "captureNowRequested"
        case .captureApproved: return "captureApproved"
        case .captureDenied: return "captureDenied"
        case .photoCaptured: return "photoCaptured"
        case .finalPhotoAvailable: return "finalPhotoAvailable"
        case .reactionSent: return "reactionSent"
        case .sessionEnded: return "sessionEnded"
        }
    }
}
