import XCTest
@testable import AllHandsOnDeck

final class NearbySessionSummaryTests: XCTestCase {
    func test_full_discoveryInfo_decodes() {
        let info: [String: String] = [
            "sessionId": "ABCDEF1234",
            "hostName": "Alexander",
            "trigger": "everyoneCanStartTimer",
            "timer": "20"
        ]
        let s = NearbySessionSummary(discoveryInfo: info, fallbackPeerName: "iPhone")
        XCTAssertNotNil(s)
        XCTAssertEqual(s?.sessionId, "ABCDEF1234")
        XCTAssertEqual(s?.hostName, "Alexander")
        XCTAssertEqual(s?.triggerPermission, .everyoneCanStartTimer)
        XCTAssertEqual(s?.timerDuration, 20)
    }

    func test_missing_sessionId_returnsNil() {
        let info: [String: String] = ["hostName": "Bob"]
        XCTAssertNil(NearbySessionSummary(discoveryInfo: info, fallbackPeerName: "iPhone"))
    }

    func test_missing_hostName_usesFallback() {
        let info: [String: String] = ["sessionId": "ABCDEF1234"]
        let s = NearbySessionSummary(discoveryInfo: info, fallbackPeerName: "iPhone-Bob")
        XCTAssertEqual(s?.hostName, "iPhone-Bob")
    }

    func test_unrecognized_trigger_defaultsToHostOnly() {
        let info: [String: String] = [
            "sessionId": "ABCDEF1234",
            "trigger": "magic_word_that_doesnt_exist"
        ]
        let s = NearbySessionSummary(discoveryInfo: info, fallbackPeerName: "iPhone")
        XCTAssertEqual(s?.triggerPermission, .hostOnly)
    }

    func test_invalid_timer_defaultsToTen() {
        let info: [String: String] = [
            "sessionId": "ABCDEF1234",
            "timer": "not-a-number"
        ]
        let s = NearbySessionSummary(discoveryInfo: info, fallbackPeerName: "iPhone")
        XCTAssertEqual(s?.timerDuration, 10)
    }

    func test_makePhotoSession_passesThroughCoreFields() {
        let info: [String: String] = [
            "sessionId": "ABCDEF1234",
            "hostName": "Alexander",
            "trigger": "viewersCanRequest",
            "timer": "30"
        ]
        let s = NearbySessionSummary(discoveryInfo: info, fallbackPeerName: "x")!
        let session = s.makePhotoSession()
        XCTAssertEqual(session.id, "ABCDEF1234")
        XCTAssertEqual(session.hostName, "Alexander")
        XCTAssertEqual(session.triggerPermission, .viewersCanRequest)
        XCTAssertEqual(session.timerDuration, 30)
    }
}
