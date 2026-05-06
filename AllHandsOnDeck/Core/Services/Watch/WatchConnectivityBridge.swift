import Foundation
import Combine
import WatchConnectivity

/// Talks to the paired Apple Watch via `WCSession`. Single host-side instance
/// pushes `WatchSnapshot` updates and surfaces `WatchCommand`s to whoever is
/// listening (the host view-model).
///
/// The watch transport is fundamentally best-effort: if the watch is not on
/// the wrist, asleep, or out of range, sends drop. We use `transferUserInfo`
/// for snapshots when the session is reachable, and `sendMessage` for
/// commands so both sides get a Bool delivery hint.
@MainActor
final class WatchConnectivityBridge: NSObject, ObservableObject {
    static let shared = WatchConnectivityBridge()

    @Published private(set) var isReachable: Bool = false
    @Published private(set) var isPaired: Bool = false

    private let session: WCSession?
    private var commandHandler: ((WatchCommand) -> Void)?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    override init() {
        if WCSession.isSupported() {
            session = WCSession.default
        } else {
            session = nil
        }
        super.init()
        session?.delegate = self
        session?.activate()
    }

    /// Subscribe to watch commands. Replaces any previous handler.
    func setCommandHandler(_ handler: @escaping (WatchCommand) -> Void) {
        self.commandHandler = handler
    }

    /// Push the current host state to the watch. Cheap to call frequently.
    func push(snapshot: WatchSnapshot) {
        guard let session, session.activationState == .activated else { return }
        guard let data = try? encoder.encode(snapshot) else { return }

        let message: [String: Any] = [
            WatchWireKey.kind: "snapshot",
            WatchWireKey.payload: data
        ]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                AppLog.session.error("watch sendMessage failed: \(error.localizedDescription)")
            }
        } else {
            // Queues until the watch wakes up.
            session.transferUserInfo(message)
        }
    }
}

extension WatchConnectivityBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Required override; reactivate so a re-paired watch resumes.
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncoming(userInfo)
    }

    private nonisolated func handleIncoming(_ message: [String: Any]) {
        guard let kind = message[WatchWireKey.kind] as? String else { return }
        if kind == "command",
           let raw = message[WatchWireKey.command] as? String,
           let cmd = WatchCommand(rawValue: raw) {
            Task { @MainActor in
                self.commandHandler?(cmd)
            }
        }
    }
}
