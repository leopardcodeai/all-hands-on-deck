import Foundation
import MultipeerConnectivity

/// Standalone browser used by NearbySessionsView to populate a discovery list.
/// Independent from the per-session MultipeerSessionTransport browser — this
/// one never connects, it only observes.
@MainActor
final class NearbySessionBrowser: NSObject, ObservableObject {
    @Published private(set) var sessions: [NearbySessionSummary] = []
    @Published private(set) var isBrowsing: Bool = false

    private let peerID: MCPeerID
    private let browser: MCNearbyServiceBrowser

    init(displayName: String) {
        let safe = MultipeerSessionTransport.sanitizedDisplayName(displayName)
        self.peerID = MCPeerID(displayName: safe)
        self.browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: MultipeerSessionTransport.serviceType
        )
        super.init()
        browser.delegate = self
    }

    func start() {
        guard !isBrowsing else { return }
        sessions.removeAll()
        browser.startBrowsingForPeers()
        isBrowsing = true
    }

    func stop() {
        guard isBrowsing else { return }
        browser.stopBrowsingForPeers()
        isBrowsing = false
    }

    deinit {
        browser.stopBrowsingForPeers()
    }
}

extension NearbySessionBrowser: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        let summary = NearbySessionSummary(
            discoveryInfo: info,
            fallbackPeerName: peerID.displayName
        )
        guard let summary else { return }
        Task { @MainActor in
            if !self.sessions.contains(where: { $0.sessionId == summary.sessionId }) {
                self.sessions.append(summary)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // We don't know which sessionId this peer was advertising once it's
        // gone, so we just rely on `start()` resetting the list when the
        // user re-enters the screen. Optional refinement: keep a peerID→id map.
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             didNotStartBrowsingForPeers error: Error) {
        AppLog.transport.error("nearby browser failed: \(error.localizedDescription)")
    }
}
