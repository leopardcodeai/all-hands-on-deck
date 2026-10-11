import Foundation
import Combine
import WatchConnectivity

/// Watch-side counterpart to the iOS `WatchConnectivityBridge`. Receives
/// `WatchSnapshot` updates from the iPhone and forwards `WatchCommand`s back.
@MainActor
final class WatchSideBridge: NSObject, ObservableObject {
    @Published private(set) var snapshot: WatchSnapshot = .empty
    @Published private(set) var isConnected: Bool = false

    private let session = WCSession.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    func send(_ command: WatchCommand) {
        let message: [String: Any] = [
            WatchWireKey.kind: "command",
            WatchWireKey.command: command.rawValue
        ]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in }
        } else {
            session.transferUserInfo(message)
        }
    }

    private nonisolated func handle(_ message: [String: Any]) {
        guard let kind = message[WatchWireKey.kind] as? String, kind == "snapshot",
              let data = message[WatchWireKey.payload] as? Data else { return }
        Task { @MainActor in
            if let snap = try? self.decoder.decode(WatchSnapshot.self, from: data) {
                self.snapshot = snap
            }
        }
    }
}

extension WatchSideBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in
            self.isConnected = (activationState == .activated)
            if self.isConnected { self.send(.requestSnapshot) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handle(message)
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handle(userInfo)
    }
}
