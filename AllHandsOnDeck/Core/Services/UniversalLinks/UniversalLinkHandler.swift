import Foundation
import Combine

/// Watches `onOpenURL` and `NSUserActivity` (universal-link) events and turns
/// them into `pendingSessionID` that root navigation routes to a viewer view.
///
/// Reuses `SessionURLParser` so the same logic that decodes QR scans handles
/// link taps from Mail / Messages / a Safari banner.
@MainActor
final class UniversalLinkHandler: ObservableObject {
    @Published var pendingSessionID: String?

    func handle(url: URL) {
        if let id = SessionURLParser.sessionID(from: url.absoluteString) {
            pendingSessionID = id
            Haptics.tap()
        }
    }

    func consume() -> String? {
        defer { pendingSessionID = nil }
        return pendingSessionID
    }
}
