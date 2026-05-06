import Foundation
import Combine
import UIKit

/// State and actions for the viewer screen.
@MainActor
final class ViewerSessionViewModel: ObservableObject {
    enum ConnectionStatus {
        case connecting, connected, notFound, ended, lost
    }

    @Published private(set) var status: ConnectionStatus = .connecting
    @Published private(set) var session: PhotoSession
    @Published private(set) var latestPreviewImage: UIImage?
    @Published private(set) var finalPhoto: CapturedPhoto?
    @Published private(set) var countdownState: CountdownState = .idle
    @Published private(set) var countdownRemaining: Int = 0
    @Published var errorMessage: String?

    let countdown = CountdownCoordinator()

    private let transport: SessionTransport
    private var subs: Set<AnyCancellable> = []
    private var wasEverConnected = false

    init(session: PhotoSession, displayName: String) {
        self.session = session
        self.transport = SessionManager.makeViewerTransport(displayName: displayName)
    }

    // MARK: - Lifecycle

    func onAppear() async {
        IdentityService.shared.record(.joinSession)
        do {
            try await transport.start(session: session)
        } catch {
            status = .notFound
            errorMessage = "Connection failed."
            return
        }

        transport.events
            .receive(on: RunLoop.main)
            .sink { [weak self] event in self?.handle(event) }
            .store(in: &subs)

        transport.connectionStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] s in self?.applyTransportStatus(s) }
            .store(in: &subs)

        // Mirror countdown state so SwiftUI observes it directly (nested
        // ObservableObject changes aren't always picked up through forwarding).
        countdown.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.countdownState = $0 }
            .store(in: &subs)
        countdown.$remainingSeconds
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.countdownRemaining = $0 }
            .store(in: &subs)
    }

    func onDisappear() {
        transport.stop()
    }

    // MARK: - Actions

    var canTrigger: Bool {
        switch session.triggerPermission {
        case .everyoneCanStartTimer, .viewersCanRequest: return true
        case .hostOnly: return false
        }
    }

    /// Direct "shoot now" — only meaningful when everyone can start the timer.
    /// Mirrors the webapp's "⚡ Now" button.
    var canTriggerNow: Bool {
        session.triggerPermission == .everyoneCanStartTimer
    }

    var triggerLabel: String {
        switch session.triggerPermission {
        case .everyoneCanStartTimer: return DesignLabels.timer(session.timerDuration)
        case .viewersCanRequest:     return DesignLabels.requestPhoto
        case .hostOnly:              return ""
        }
    }

    func tapTrigger() async {
        guard canTrigger, !countdown.state.isActive else { return }
        await transport.send(.captureRequested(by: transport.localParticipantID))
        Haptics.tap()
    }

    func tapTriggerNow() async {
        guard canTriggerNow, !countdown.state.isActive else { return }
        await transport.send(.captureNowRequested(by: transport.localParticipantID))
        Haptics.tap()
    }

    func sendReady(_ ready: Bool) async {
        await transport.send(.participantReadyChanged(
            participantID: transport.localParticipantID,
            isReady: ready
        ))
    }

    func clearFinalPhoto() {
        finalPhoto = nil
    }
    func sendReaction(_ reaction: Reaction) async {
        IdentityService.shared.record(.sendReaction)
        await transport.send(.reactionSent(
            by: transport.localParticipantID,
            reaction: reaction.rawValue
        ))
    }

    // MARK: - Inbound

    private func applyTransportStatus(_ s: TransportConnectionStatus) {
        switch s {
        case .browsing, .connecting, .advertising, .idle:
            if !wasEverConnected, finalPhoto == nil { status = .connecting }
        case .connected:
            wasEverConnected = true
            status = .connected
        case .notFound:
            status = .notFound
        case .disconnected:
            if status == .connected, finalPhoto == nil { status = .lost }
            else if status != .connected { status = .notFound }
        case .failed:
            status = .notFound
        }
    }

    private func handle(_ event: SessionEvent) {
        switch event {
        case .sessionMetadata(let updated):
            session.hostName = updated.hostName
            session.timerDuration = updated.timerDuration
            session.triggerPermission = updated.triggerPermission
            session.allowWebJoin = updated.allowWebJoin
            session.allowFinalPhotoDownload = updated.allowFinalPhotoDownload
            session.isDiscoverableNearby = updated.isDiscoverableNearby
            session.expiresAt = updated.expiresAt
            session.participants = updated.participants

        case .countdownStarted(let photoAt, let duration, _):
            countdown.armRunning(photoAt: photoAt, duration: duration)
            finalPhoto = nil

        case .countdownCancelled:
            countdown.cancel()
            finalPhoto = nil

        case .photoCaptured:
            countdown.markCompleted()

        case .finalPhotoAvailable(let id, let jpeg):
            finalPhoto = CapturedPhoto(id: id, imageData: jpeg)

        case .previewFrame(let jpeg, _):
            if let img = UIImage(data: jpeg) {
                latestPreviewImage = img
            }

        case .sessionEnded:
            status = .ended

        default:
            break
        }
    }
}
