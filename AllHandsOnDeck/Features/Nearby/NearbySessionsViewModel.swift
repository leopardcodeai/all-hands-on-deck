import Foundation
import Combine

@MainActor
final class NearbySessionsViewModel: ObservableObject {
    @Published private(set) var sessions: [NearbySessionSummary] = []
    @Published private(set) var isBrowsing: Bool = false

    private let browser: NearbySessionBrowser
    private var subs: Set<AnyCancellable> = []

    init(displayName: String) {
        self.browser = NearbySessionBrowser(displayName: displayName)

        browser.$sessions
            .receive(on: RunLoop.main)
            .assign(to: &$sessions)
        browser.$isBrowsing
            .receive(on: RunLoop.main)
            .assign(to: &$isBrowsing)
    }

    func start() { browser.start() }
    func stop() { browser.stop() }
}
