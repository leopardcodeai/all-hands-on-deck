import XCTest
@testable import AllHandsOnDeck

final class SessionWireMessageTests: XCTestCase {
    func test_envelope_roundTrip_preservesEverything() throws {
        let event: SessionEvent = .countdownStarted(
            photoAt: Date(timeIntervalSinceReferenceDate: 1_000),
            duration: 10,
            startedBy: "host-id"
        )
        let original = SessionWireMessage(
            sessionId: "ABCDEF1234",
            senderId: "host-id",
            createdAt: Date(timeIntervalSinceReferenceDate: 999),
            event: event
        )

        let data = try original.encoded()
        let decoded = try SessionWireMessage.decode(data)

        XCTAssertEqual(decoded.sessionId, "ABCDEF1234")
        XCTAssertEqual(decoded.senderId, "host-id")
        if case .countdownStarted(let photoAt, let dur, let by) = decoded.event {
            XCTAssertEqual(dur, 10)
            XCTAssertEqual(by, "host-id")
            XCTAssertEqual(photoAt.timeIntervalSinceReferenceDate, 1_000, accuracy: 0.001)
        } else {
            XCTFail("Expected .countdownStarted")
        }
    }

    func test_kind_routing() {
        let session = PhotoSession(hostName: "Captain")
        let cases: [(SessionEvent, SessionWireMessage.Kind)] = [
            (.sessionMetadata(session), .metadata),
            (.previewFrame(jpeg: Data([0xFF]), capturedAt: Date()), .previewFrame),
            (.finalPhotoAvailable(photoID: "x", jpeg: Data([0xFF])), .finalPhoto),
            (.captureRequested(by: "id"), .triggerRequest),
            (.captureNowRequested(by: "id"), .triggerRequest),
            (.reactionSent(by: "id", reaction: Reaction.ready.rawValue), .reaction),
            (.countdownStarted(photoAt: Date(), duration: 10, startedBy: "id"), .event)
        ]
        for (event, expected) in cases {
            let wm = SessionWireMessage(
                sessionId: "X", senderId: "Y",
                createdAt: Date(), event: event
            )
            XCTAssertEqual(wm.kind, expected, "kind for \(event)")
        }
    }

    func test_captureNowRequested_roundTrip() throws {
        // The webapp's "⚡ Now" button sends this event; iOS host must decode
        // it back to the matching enum case so triggerPermission routing works.
        let event: SessionEvent = .captureNowRequested(by: "viewer-42")
        let wm = SessionWireMessage(sessionId: "ABCDEF", senderId: "viewer-42",
                                    createdAt: Date(), event: event)
        let decoded = try SessionWireMessage.decode(wm.encoded())
        if case .captureNowRequested(let by) = decoded.event {
            XCTAssertEqual(by, "viewer-42")
        } else {
            XCTFail("Expected .captureNowRequested, got \(decoded.event)")
        }
    }

    func test_previewFrame_largeData_roundTrip() throws {
        // ~50KB blob — the typical size of one 640px JPEG q=0.5.
        let data = Data(repeating: 0xAB, count: 50_000)
        let event: SessionEvent = .previewFrame(jpeg: data, capturedAt: Date())
        let wm = SessionWireMessage(sessionId: "A", senderId: "B", createdAt: Date(), event: event)

        let encoded = try wm.encoded()
        let decoded = try SessionWireMessage.decode(encoded)

        if case .previewFrame(let jpeg, _) = decoded.event {
            XCTAssertEqual(jpeg, data)
        } else {
            XCTFail("Expected .previewFrame")
        }
    }
}
