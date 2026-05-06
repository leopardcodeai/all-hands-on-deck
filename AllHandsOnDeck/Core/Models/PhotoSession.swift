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
    var joinToken: JoinToken?
    var participants: [Participant]

    init(
        id: String = Self.makeShortID(),
        hostName: String,
        createdAt: Date = Date(),
        ttlMinutes: Int = 10,
        timerDuration: Int = 10,
        triggerPermission: TriggerPermission = .everyoneCanStartTimer,
        isDiscoverableNearby: Bool = true,
        allowWebJoin: Bool = true,
        allowFinalPhotoDownload: Bool = true,
        joinToken: JoinToken? = nil,
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
        self.joinToken = joinToken
        self.participants = participants
    }

    /// 10-character random ID. Not guessable, short enough to display.
    static func makeShortID() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // omits ambiguous chars
        return String((0..<10).map { _ in alphabet.randomElement()! })
    }

    /// Override the join base URL via UserDefaults["joinBaseURL"] or the
    /// WEB_JOIN_BASE_URL build setting to point at the deployed web viewer.
    var joinURL: URL {
        let base = UserDefaults.standard.string(forKey: "joinBaseURL")
            ?? Bundle.main.object(forInfoDictionaryKey: "WEB_JOIN_BASE_URL") as? String
            ?? ""
        let pathURL: URL
        if !base.isEmpty {
            pathURL = URL(string: "\(base)/join/\(id)")!
        } else {
            pathURL = URL(string: "allhands://join/\(id)")!
        }
        guard let joinToken else { return pathURL }

        var components = URLComponents(url: pathURL, resolvingAgainstBaseURL: false)!
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "session_id", value: id))
        queryItems.append(URLQueryItem(name: "token", value: joinToken.value))
        queryItems.append(URLQueryItem(name: "expires_at", value: ISO8601DateFormatter().string(from: joinToken.expiresAt)))
        components.queryItems = queryItems
        return components.url!
    }
}
