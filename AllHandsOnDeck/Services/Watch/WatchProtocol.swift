import Foundation

/// Shared wire format between the iPhone host and the paired Apple Watch.
/// Add this file to **both** the iOS target and the Watch App target in Xcode
/// (Target Membership checkbox in the File Inspector).
///
/// Channel: `WCSession.sendMessage` (small JSON dictionaries). We don't push
/// preview frames to the watch — too expensive, too small a screen. The watch
/// only sees session-level state and emits high-level commands.
enum WatchCommand: String, Codable, Sendable {
    /// Watch tells phone: start the timer with the host-configured duration.
    case startTimer
    /// Watch tells phone: capture immediately, no countdown.
    case captureNow
    /// Watch tells phone: abort an in-flight countdown.
    case cancelTimer
    /// Watch tells phone: send the latest session snapshot back.
    case requestSnapshot
}

/// Phone tells watch: here is everything you need to render. Sent on every
/// state change so the watch's view-model is a pure mirror.
struct WatchSnapshot: Codable, Sendable {
    enum CountdownState: String, Codable, Sendable { case idle, running, capturing, completed }

    var sessionID: String?
    var hostName: String
    var participantCount: Int
    var timerDuration: Int
    var canTrigger: Bool
    var countdown: CountdownState
    var photoAtEpochMs: Double?      // for the watch's local ticker
    var lastReactionLabel: String?
    var lastReactionFrom: String?
    var generatedAt: Date

    static let empty = Self(
        sessionID: nil,
        hostName: "Captain",
        participantCount: 0,
        timerDuration: 10,
        canTrigger: true,
        countdown: .idle,
        photoAtEpochMs: nil,
        lastReactionLabel: nil,
        lastReactionFrom: nil,
        generatedAt: Date()
    )
}

/// Keys used inside the WCSession message dictionaries.
enum WatchWireKey {
    static let kind = "kind"            // "command" | "snapshot"
    static let command = "command"      // raw value of WatchCommand
    static let payload = "payload"      // JSON-encoded WatchSnapshot
}
