import Foundation
import Combine

/// Single source of truth for "what name / rank does this device show".
///
/// Priority:
///   1. Custom name override (user typed something)
///   2. Game Center alias + earned rank  → "⚓ First Mate aka AlexBrunker"
///   3. Random rank (no GC, no override) → "🧭 Navigator"
@MainActor
final class IdentityService: ObservableObject {
    static let shared = IdentityService()

    // MARK: - Persisted settings

    /// When true, pull identity from Game Center if authenticated.
    @Published var useGameCenter: Bool {
        didSet { UserDefaults.standard.set(useGameCenter, forKey: "identity.useGameCenter") }
    }

    /// Non-empty means "user typed a custom name" — overrides everything.
    @Published var customName: String {
        didSet { UserDefaults.standard.set(customName, forKey: "identity.customName") }
    }

    // MARK: - Derived

    /// The rank earned based on accumulated action points.
    @Published private(set) var earnedRank: PirateRank = .cabinBoy

    private var actionPoints: Int {
        get { UserDefaults.standard.integer(forKey: "identity.actionPoints") }
        set {
            UserDefaults.standard.set(newValue, forKey: "identity.actionPoints")
            earnedRank = PirateRank.rank(for: newValue)
        }
    }

    private lazy var gc = GameCenterService.shared
    private var gcSub: AnyCancellable?

    // MARK: - Init

    private init() {
        useGameCenter = UserDefaults.standard.bool(forKey: "identity.useGameCenter")
        customName    = UserDefaults.standard.string(forKey: "identity.customName") ?? ""
        earnedRank    = PirateRank.rank(for: UserDefaults.standard.integer(forKey: "identity.actionPoints"))

        // Defer GC access until first use — avoids touching GameKit on the
        // launch critical path for users who haven't enabled Game Center.
        if UserDefaults.standard.bool(forKey: "identity.useGameCenter") {
            gcSub = GameCenterService.shared.$isAuthenticated
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        }
    }

    // MARK: - Resolved identity

    /// The name sent to peers (stored in sessions, shown on crew lists).
    var displayName: String {
        if !customName.trimmingCharacters(in: .whitespaces).isEmpty {
            return customName
        }
        if useGameCenter, gc.isAuthenticated, let alias = gc.alias {
            return "\(earnedRank.emoji) \(earnedRank.title) aka \(alias)"
        }
        return "\(earnedRank.emoji) \(earnedRank.title)"
    }

    /// Short badge shown in the home-screen identity chip.
    var rankBadge: String {
        "\(earnedRank.emoji) \(earnedRank.title)"
    }

    // MARK: - Point tracking

    enum Action { case hostSession, capturePhoto, joinSession, sendReaction, acceptBurst }

    func record(_ action: Action) {
        let delta: Int
        switch action {
        case .hostSession:   delta = 5
        case .capturePhoto:  delta = 3
        case .joinSession:   delta = 2
        case .sendReaction:  delta = 1
        case .acceptBurst:   delta = 2
        }
        let before = earnedRank
        actionPoints += delta
        let after = earnedRank
        if after.rawValue > before.rawValue {
            gc.reportRankAchievement(after)
        }
    }

    // MARK: - Game Center

    func enableGameCenter() async {
        useGameCenter = true
        if gcSub == nil {
            gcSub = GameCenterService.shared.$isAuthenticated
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        }
        await gc.authenticate()
    }
}
