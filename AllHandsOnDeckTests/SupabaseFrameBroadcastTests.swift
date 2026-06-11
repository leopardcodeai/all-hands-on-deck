import XCTest
@testable import AllHandsOnDeck

/// Wire-format tests for the Realtime Broadcast frame path: the REST body
/// the host POSTs and the Phoenix websocket messages the viewer decodes.
/// Pure JSON fixtures — no networking.
final class SupabaseFrameBroadcastTests: XCTestCase {
    private let sessionID = "0b8de36a-1111-2222-3333-444455556666"

    // MARK: - Outgoing REST body

    func test_requestBody_matchesVerifiedBroadcastShape() throws {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let capturedAt = Date(timeIntervalSince1970: 1_770_000_000)

        let body = try SupabaseFrameBroadcast.requestBody(
            sessionID: sessionID,
            jpeg: jpeg,
            capturedAt: capturedAt,
            senderId: "host-participant-1"
        )

        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)

        let message = try XCTUnwrap(messages.first)
        XCTAssertEqual(message["topic"] as? String, "session-frames:\(sessionID)")
        XCTAssertEqual(message["event"] as? String, "preview_frame")

        let payload = try XCTUnwrap(message["payload"] as? [String: Any])
        XCTAssertEqual(payload["jpeg"] as? String, jpeg.base64EncodedString())
        XCTAssertEqual(payload["senderId"] as? String, "host-participant-1")

        // capturedAt must be ISO8601 and round-trip back to the same instant.
        let capturedAtString = try XCTUnwrap(payload["capturedAt"] as? String)
        let parsed = try XCTUnwrap(SupabaseFrameBroadcast.parseISO8601(capturedAtString))
        XCTAssertEqual(parsed.timeIntervalSince1970, capturedAt.timeIntervalSince1970, accuracy: 1.0)
    }

    func test_requestBody_keysAreNotSnakeCased() throws {
        // The transport's table encoder snake_cases keys; the broadcast body
        // must NOT (capturedAt/senderId are camelCase on the wire).
        let body = try SupabaseFrameBroadcast.requestBody(
            sessionID: sessionID,
            jpeg: Data([0x01]),
            capturedAt: Date(),
            senderId: "p1"
        )
        let text = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(text.contains("\"capturedAt\""))
        XCTAssertTrue(text.contains("\"senderId\""))
        XCTAssertFalse(text.contains("captured_at"))
        XCTAssertFalse(text.contains("sender_id"))
    }

    // MARK: - Incoming Phoenix broadcasts

    private func phoenixBroadcastFixture(
        jpegBase64: String,
        capturedAt: String,
        senderId: String
    ) -> Data {
        Data("""
        {
            "topic": "realtime:session-frames:\(sessionID)",
            "event": "broadcast",
            "payload": {
                "event": "preview_frame",
                "type": "broadcast",
                "payload": {
                    "jpeg": "\(jpegBase64)",
                    "capturedAt": "\(capturedAt)",
                    "senderId": "\(senderId)"
                }
            },
            "ref": null
        }
        """.utf8)
    }

    func test_decodeIncomingFrame_decodesNestedPayload() throws {
        let jpeg = Data([0xFF, 0xD8, 0xAB, 0xCD])
        let fixture = phoenixBroadcastFixture(
            jpegBase64: jpeg.base64EncodedString(),
            capturedAt: "2026-06-11T12:34:56Z",
            senderId: "host-participant-1"
        )

        let frame = try XCTUnwrap(SupabaseFrameBroadcast.decodeIncomingFrame(fixture))
        XCTAssertEqual(frame.jpeg, jpeg)
        XCTAssertEqual(frame.senderId, "host-participant-1")

        var components = DateComponents()
        (components.year, components.month, components.day) = (2026, 6, 11)
        (components.hour, components.minute, components.second) = (12, 34, 56)
        components.timeZone = TimeZone(identifier: "UTC")
        let expected = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: components))
        XCTAssertEqual(frame.capturedAt.timeIntervalSince1970,
                       expected.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_decodeIncomingFrame_acceptsFractionalSeconds() throws {
        // The web client emits fractional-second timestamps.
        let fixture = phoenixBroadcastFixture(
            jpegBase64: Data([0x01]).base64EncodedString(),
            capturedAt: "2026-06-11T12:34:56.789Z",
            senderId: "p1"
        )
        let frame = try XCTUnwrap(SupabaseFrameBroadcast.decodeIncomingFrame(fixture))
        XCTAssertEqual(frame.senderId, "p1")
    }

    func test_decodeIncomingFrame_ignoresPhoenixControlMessages() {
        let reply = Data("""
        {"topic":"realtime:session-frames:\(sessionID)","event":"phx_reply",\
        "payload":{"status":"ok","response":{}},"ref":"1"}
        """.utf8)
        let heartbeat = Data("""
        {"topic":"phoenix","event":"phx_reply","payload":{"status":"ok","response":{}},"ref":"2"}
        """.utf8)
        let system = Data("""
        {"topic":"realtime:session-frames:\(sessionID)","event":"system",\
        "payload":{"status":"ok","message":"Subscribed to realtime"},"ref":null}
        """.utf8)

        XCTAssertNil(SupabaseFrameBroadcast.decodeIncomingFrame(reply))
        XCTAssertNil(SupabaseFrameBroadcast.decodeIncomingFrame(heartbeat))
        XCTAssertNil(SupabaseFrameBroadcast.decodeIncomingFrame(system))
    }

    func test_decodeIncomingFrame_ignoresOtherBroadcastEvents() {
        let other = Data("""
        {"topic":"realtime:session-frames:\(sessionID)","event":"broadcast",\
        "payload":{"event":"something_else","type":"broadcast",\
        "payload":{"jpeg":"AQ==","capturedAt":"2026-06-11T12:00:00Z","senderId":"p1"}},"ref":null}
        """.utf8)
        XCTAssertNil(SupabaseFrameBroadcast.decodeIncomingFrame(other))
    }

    func test_decodeIncomingFrame_rejectsInvalidBase64() {
        let fixture = phoenixBroadcastFixture(
            jpegBase64: "not-base64!!!",
            capturedAt: "2026-06-11T12:00:00Z",
            senderId: "p1"
        )
        XCTAssertNil(SupabaseFrameBroadcast.decodeIncomingFrame(fixture))
    }

    func test_topic_usesSessionUUIDNotJoinCode() {
        XCTAssertEqual(
            SupabaseFrameBroadcast.topic(forSessionID: sessionID),
            "session-frames:\(sessionID)"
        )
    }
}
