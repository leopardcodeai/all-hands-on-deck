import XCTest
@testable import AllHandsOnDeck

final class SessionURLParserTests: XCTestCase {
    func test_customScheme() {
        let id = SessionURLParser.sessionID(from: "allhands://join?session=ABCDEF1234")
        XCTAssertEqual(id, "ABCDEF1234")
    }

    func test_customScheme_noSession_isNil() {
        XCTAssertNil(SessionURLParser.sessionID(from: "allhands://join?other=foo"))
    }

    func test_customScheme_tooShort_isNil() {
        XCTAssertNil(SessionURLParser.sessionID(from: "allhands://join?session=ABC"))
    }

    func test_universalLink_extractsLastPathComponent() {
        let id = SessionURLParser.sessionID(from: "https://allhands.leopardcode.ai/join/QWERTY1234")
        XCTAssertEqual(id, "QWERTY1234")
    }

    func test_universalLink_withTrailingSlash() {
        let id = SessionURLParser.sessionID(from: "https://example.com/join/QWERTY1234/")
        XCTAssertEqual(id, "QWERTY1234")
    }

    func test_universalLink_withQuery() {
        let id = SessionURLParser.sessionID(from: "https://example.com/join/QWERTY1234?ref=email")
        XCTAssertEqual(id, "QWERTY1234")
    }

    func test_joinRequest_readsSessionIDAndShortLivedToken() {
        let request = SessionURLParser.joinRequest(
            from: "https://example.com/join/QWERTY1234?session_id=QWERTY1234&token=abc&expires_at=2026-05-06T08:10:00Z"
        )

        XCTAssertEqual(request?.sessionID, "QWERTY1234")
        XCTAssertEqual(request?.token, "abc")
    }

    func test_customSchemePath_readsSessionID() {
        let id = SessionURLParser.sessionID(from: "allhands://join/QWERTY1234?token=abc")
        XCTAssertEqual(id, "QWERTY1234")
    }

    func test_bareCode_uppercased() {
        let id = SessionURLParser.sessionID(from: "abcdef1234")
        XCTAssertEqual(id, "ABCDEF1234")
    }

    func test_bareCode_tooLong_isNil() {
        let huge = String(repeating: "A", count: 50)
        XCTAssertNil(SessionURLParser.sessionID(from: huge))
    }

    func test_garbageInput_isNil() {
        XCTAssertNil(SessionURLParser.sessionID(from: "    "))
        XCTAssertNil(SessionURLParser.sessionID(from: "ftp://wat/lol"))
        XCTAssertNil(SessionURLParser.sessionID(from: "  ABC ?-=+"))
    }

    func test_paddedInput_isTrimmed() {
        let id = SessionURLParser.sessionID(from: "  ABCDEF1234  ")
        XCTAssertEqual(id, "ABCDEF1234")
    }
}
