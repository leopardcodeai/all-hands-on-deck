import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var lastKnownSessionID: String?

    private let identity = IdentityService.shared
    private var sub: AnyCancellable?

    var hostName: String { identity.displayName }

    init() {
        sub = identity.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    func remember(sessionID: String) {
        lastKnownSessionID = sessionID
    }
}
