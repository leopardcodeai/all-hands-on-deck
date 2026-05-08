import GameKit
import Foundation
/// Wraps Game Center authentication and achievement reporting.
/// Opt-in: the user triggers authentication by enabling GC identity in settings.
@MainActor
final class GameCenterService: ObservableObject {
    static let shared = GameCenterService()

    @Published private(set) var alias: String?
    @Published private(set) var isAuthenticated: Bool = false

    private init() {}

    func authenticate() async {
        guard !GKLocalPlayer.local.isAuthenticated else {
            alias = GKLocalPlayer.local.alias
            isAuthenticated = true
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            GKLocalPlayer.local.authenticateHandler = { [weak self] _, _ in
                Task { @MainActor in
                    let authenticated = GKLocalPlayer.local.isAuthenticated
                    self?.alias = authenticated ? GKLocalPlayer.local.alias : nil
                    self?.isAuthenticated = authenticated
                    continuation.resume()
                }
            }
        }
    }

    /// Report a rank achievement at 100% completion (idempotent — GC ignores downgrades).
    func reportRankAchievement(_ rank: PirateRank) {
        guard isAuthenticated, let id = rank.achievementID else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = 100.0
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { _ in }
    }
}

