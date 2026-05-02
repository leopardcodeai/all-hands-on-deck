import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var lastKnownSessionID: String?

    private let identity = IdentityService.shared

    var hostName: String { identity.displayName }

    init() {}

    func remember(sessionID: String) {
        lastKnownSessionID = sessionID
    }
}
