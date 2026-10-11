import Foundation

struct SessionPolicy: Hashable, Codable, Sendable {
    let maxSessionDurationMinutes: Int
    let maxP2PViewers: Int
    let shortLivedTokenTTLMinutes: Int
    let realtimeMessagesPerMinute: Int
    let maxTurnMinutesPerSession: Int
    let quotaWarningThresholds: [Double]
    let videoStorageTables: [String]
    let webViewersFeatureStage: String

    static let mvp = SessionPolicy(
        maxSessionDurationMinutes: 10,
        maxP2PViewers: 3,
        shortLivedTokenTTLMinutes: 10,
        realtimeMessagesPerMinute: 120,
        maxTurnMinutesPerSession: 2,
        quotaWarningThresholds: [0.5, 0.8, 0.95],
        videoStorageTables: [],
        webViewersFeatureStage: "beta"
    )

    func canJoinP2P(currentViewerCount: Int) -> Bool {
        currentViewerCount < maxP2PViewers
    }

    func shouldUseTURN(explicitFallbackRequested: Bool, usedMinutes: Int) -> Bool {
        explicitFallbackRequested && usedMinutes < maxTurnMinutesPerSession
    }

    func quotaWarningLevel(for usageRatio: Double) -> Int? {
        if usageRatio >= quotaWarningThresholds[2] { return 95 }
        if usageRatio >= quotaWarningThresholds[1] { return 80 }
        if usageRatio >= quotaWarningThresholds[0] { return 50 }
        return nil
    }
}

struct JoinToken: Hashable, Codable, Sendable {
    let sessionID: String
    let value: String
    let issuedAt: Date
    let expiresAt: Date

    init(
        sessionID: String,
        value: String = UUID().uuidString,
        issuedAt: Date = Date(),
        ttlMinutes: Int = SessionPolicy.mvp.shortLivedTokenTTLMinutes
    ) {
        self.sessionID = sessionID
        self.value = value
        self.issuedAt = issuedAt
        self.expiresAt = issuedAt.addingTimeInterval(TimeInterval(ttlMinutes * 60))
    }

    func isValid(now: Date = Date()) -> Bool {
        now <= expiresAt
    }
}
