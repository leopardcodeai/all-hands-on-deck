import Foundation

/// The shared session state. The host owns the canonical copy and broadcasts updates.
struct PhotoSession: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var hostName: String
    var createdAt: Date
    var expiresAt: Date
    var timerDuration: Int
    var triggerPermission: TriggerPermission
    var isDiscoverableNearby: Bool
    var allowWebJoin: Bool
    var allowFinalPhotoDownload: Bool
    var participants: [Participant]

    init(
        id: String = PhotoSession.makeShortID(),
        hostName: String,
        createdAt: Date = Date(),
        ttlMinutes: Int = 10,
        timerDuration: Int = 10,
        triggerPermission: TriggerPermission = .everyoneCanStartTimer,
        isDiscoverableNearby: Bool = true,
        allowWebJoin: Bool = true,
        allowFinalPhotoDownload: Bool = true,
        participants: [Participant] = []
    ) {
        self.id = id
        self.hostName = hostName
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(TimeInterval(ttlMinutes * 60))
        self.timerDuration = timerDuration
        self.triggerPermission = triggerPermission
        self.isDiscoverableNearby = isDiscoverableNearby
        self.allowWebJoin = allowWebJoin
        self.allowFinalPhotoDownload = allowFinalPhotoDownload
        self.participants = participants
    }

    /// 10-character random ID. Not guessable, short enough to display.
    static func makeShortID() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // omits ambiguous chars
        return String((0..<10).map { _ in alphabet.randomElement()! })
    }

    /// Override the join base URL via UserDefaults["joinBaseURL"] to point to
    /// your local Vite dev server (e.g. `http://192.168.1.10:5173`) when
    /// testing the web viewer end-to-end.
    var joinURL: URL {
        let base = UserDefaults.standard.string(forKey: "joinBaseURL")
            ?? "https://all-hands-on-deck-ae29e.web.app"
        return URL(string: "\(base)/join/\(id)")!
    }
}
