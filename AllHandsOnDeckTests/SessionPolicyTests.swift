import XCTest
@testable import AllHandsOnDeck

final class SessionPolicyTests: XCTestCase {
    func test_mvpPolicy_hasCostControls() {
        let policy = SessionPolicy.mvp

        XCTAssertEqual(policy.maxSessionDurationMinutes, 10)
        XCTAssertEqual(policy.maxP2PViewers, 3)
        XCTAssertGreaterThanOrEqual(policy.shortLivedTokenTTLMinutes, 5)
        XCTAssertLessThanOrEqual(policy.shortLivedTokenTTLMinutes, 15)
        XCTAssertLessThanOrEqual(policy.realtimeMessagesPerMinute, 120)
        XCTAssertEqual(policy.webViewersFeatureStage, "beta")
    }

    func test_p2pViewerLimit_rejectsFourthViewer() {
        XCTAssertTrue(SessionPolicy.mvp.canJoinP2P(currentViewerCount: 2))
        XCTAssertFalse(SessionPolicy.mvp.canJoinP2P(currentViewerCount: 3))
    }

    func test_joinToken_isShortLivedAndEncodedInJoinURL() throws {
        let issuedAt = Date(timeIntervalSince1970: 1_777_705_200)
        let token = JoinToken(sessionID: "SESSION123", issuedAt: issuedAt, ttlMinutes: 10)
        let session = PhotoSession(id: "SESSION123", hostName: "Captain", joinToken: token)

        XCTAssertTrue(token.isValid(now: issuedAt.addingTimeInterval(600)))
        XCTAssertFalse(token.isValid(now: issuedAt.addingTimeInterval(601)))
        XCTAssertEqual(session.joinURL.query?.contains("token="), true)
    }

    func test_turnFallback_requiresExplicitRequestAndHardLimit() {
        let policy = SessionPolicy.mvp

        XCTAssertFalse(policy.shouldUseTURN(explicitFallbackRequested: false, usedMinutes: 0))
        XCTAssertTrue(policy.shouldUseTURN(explicitFallbackRequested: true, usedMinutes: 0))
        XCTAssertFalse(policy.shouldUseTURN(explicitFallbackRequested: true, usedMinutes: policy.maxTurnMinutesPerSession))
    }

    func test_noVideoDataStoredInSupabase() {
        XCTAssertTrue(SessionPolicy.mvp.videoStorageTables.isEmpty)
    }
}
