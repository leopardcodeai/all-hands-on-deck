import Foundation
import Combine
import MultipeerConnectivity
import UIKit

/// Real peer-to-peer transport.
///
/// - **Host:** advertises with `MCNearbyServiceAdvertiser`, accepts every
///   invitation that targets its session, and broadcasts events to all
///   connected peers via `MCSession`.
/// - **Viewer:** browses with `MCNearbyServiceBrowser`, invites the first
///   peer whose discoveryInfo carries the matching `sessionId`, and emits
///   `participantJoined` once the MCSession reports `.connected`.
///
/// Reliability:
/// - Control / metadata / final-photo events use `.reliable`.
/// - Preview frames use `.unreliable` so they can drop under congestion
///   without queuing up behind one another.
@MainActor
final class MultipeerSessionTransport: NSObject, SessionTransport {
    // MARK: - Service constants

    /// 8 chars, only `[a-z0-9-]`, ≤ 15. Must match Bonjour entries in Info.plist.
    static let serviceType = "allhands"

    /// MCPeerID requires a 1–63 utf8 char display name.
    static func sanitizedDisplayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.isEmpty ? UIDevice.current.name : trimmed
        let bytes = Array(candidate.utf8.prefix(63))
        return String(decoding: bytes, as: UTF8.self)
    }

    // MARK: - SessionTransport

    let role: SessionRole
    let localParticipantID: String

    private let eventsSubject = PassthroughSubject<SessionEvent, Never>()
    var events: AnyPublisher<SessionEvent, Never> { eventsSubject.eraseToAnyPublisher() }

    private let statusSubject = CurrentValueSubject<TransportConnectionStatus, Never>(.idle)
    var connectionStatus: AnyPublisher<TransportConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    // MARK: - Multipeer

    private let displayName: String
    private let peerID: MCPeerID
    private let mcSession: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var photoSession: PhotoSession?
    private var connectTimeoutTask: Task<Void, Never>?

    // MARK: - Init

    init(role: SessionRole,
         displayName: String,
         localParticipantID: String = UUID().uuidString) {
        self.role = role
        self.localParticipantID = localParticipantID
        self.displayName = Self.sanitizedDisplayName(displayName)
        self.peerID = MCPeerID(displayName: self.displayName)
        self.mcSession = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        super.init()
        mcSession.delegate = self
    }

    // MARK: - Lifecycle

    func start(session: PhotoSession) async throws {
        photoSession = session
        switch role {
        case .host:   startAdvertising(session: session)
        case .viewer: startBrowsing(session: session)
        }
    }

    func stop() {
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil
        mcSession.disconnect()
        statusSubject.send(.idle)
    }

    // MARK: - Send

    func send(_ event: SessionEvent) async {
        guard let sessionId = photoSession?.id else { return }
        let peers = mcSession.connectedPeers
        guard !peers.isEmpty else { return }

        let envelope = SessionWireMessage(
            sessionId: sessionId,
            senderId: localParticipantID,
            createdAt: Date(),
            event: event
        )
        // Preview frames use .reliable — JSON/base64 encoding inflates them
        // to 40-60 KB which can exceed MCSession's unreliable-mode threshold
        // and silently drop. isWritingFrame in HostSessionViewModel already
        // ensures only one frame is in-flight, preventing reliable-mode queuing.
        let mode: MCSessionSendDataMode = .reliable

        do {
            let data = try envelope.encoded()
            try mcSession.send(data, toPeers: peers, with: mode)
        } catch {
            AppLog.transport.error("send failed (\(envelope.kind)): \(error.localizedDescription)")
        }
    }

    // MARK: - Host advertising

    private func startAdvertising(session: PhotoSession) {
        let info: [String: String] = [
            "sessionId": session.id,
            "hostName": session.hostName,
            "trigger": session.triggerPermission.rawValue,
            "timer": String(session.timerDuration)
        ]
        // MCNearbyServiceAdvertiser caps total discovery info at ~400 bytes;
        // keep entries short. Drop anything we don't strictly need if it
        // grows past that in the future.
        _ = info // (reserved for future entries)

        let adv = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: info,
            serviceType: Self.serviceType
        )
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
        statusSubject.send(.advertising)
    }

    // MARK: - Viewer browsing

    private func startBrowsing(session: PhotoSession) {
        let br = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        br.delegate = self
        br.startBrowsingForPeers()
        browser = br
        statusSubject.send(.browsing)

        // 12s window to find + connect, then surface notFound to the UI.
        connectTimeoutTask?.cancel()
        connectTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 12 * 1_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if self.mcSession.connectedPeers.isEmpty {
                self.statusSubject.send(.notFound)
            }
        }
    }
}

// MARK: - MCSessionDelegate

extension MultipeerSessionTransport: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connecting:
                self.statusSubject.send(.connecting)
            case .connected:
                self.connectTimeoutTask?.cancel()
                self.connectTimeoutTask = nil
                self.statusSubject.send(.connected)
                if self.role == .viewer {
                    let me = Participant(
                        id: self.localParticipantID,
                        displayName: self.displayName,
                        role: .viewer,
                        connectionType: .nativeNearby
                    )
                    await self.send(.participantJoined(me))
                }
            case .notConnected:
                if self.role == .host {
                    // Host stays "live" — we're still advertising and ready
                    // to accept the next viewer. The LIVE pill must not flip
                    // to OFFLINE just because one viewer dropped.
                    self.eventsSubject.send(.participantLeft(participantID: peerID.displayName))
                    if self.mcSession.connectedPeers.isEmpty {
                        self.statusSubject.send(.advertising)
                    }
                } else if self.mcSession.connectedPeers.isEmpty {
                    // Viewer: distinguish never-connected from connection-lost.
                    let current = self.statusSubject.value
                    let next: TransportConnectionStatus
                    switch current {
                    case .browsing, .connecting: next = .notFound
                    case .connected:             next = .disconnected
                    default:                     next = .disconnected
                    }
                    self.statusSubject.send(next)
                }
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Decode off the delegate queue if it gets heavy; for now JSON decode
        // of small envelopes (and ~50KB JPEGs for preview frames) is fine.
        Task { @MainActor in
            do {
                let envelope = try SessionWireMessage.decode(data)
                self.eventsSubject.send(envelope.event)
            } catch {
                AppLog.transport.error("decode failed: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                             withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate (host)

extension MultipeerSessionTransport: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Accept any invite that names our sessionId in the context. Step 1
        // nice-to-have; today we accept all invitations targeting this advertiser.
        Task { @MainActor in
            invitationHandler(true, self.mcSession)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            self.statusSubject.send(.failed(error.localizedDescription))
        }
        AppLog.transport.error("advertiser failed: \(error.localizedDescription)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate (viewer)

extension MultipeerSessionTransport: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String : String]?) {
        Task { @MainActor in
            guard self.role == .viewer else { return }
            guard let target = self.photoSession?.id else { return }
            guard info?["sessionId"] == target else { return }
            // Only invite once.
            if self.mcSession.connectedPeers.contains(peerID) { return }
            self.statusSubject.send(.connecting)
            let context = target.data(using: .utf8)
            browser.invitePeer(peerID, to: self.mcSession, withContext: context, timeout: 10)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // Handled via MCSessionState.notConnected when the session itself drops.
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.statusSubject.send(.failed(error.localizedDescription))
        }
        AppLog.transport.error("browser failed: \(error.localizedDescription)")
    }
}

