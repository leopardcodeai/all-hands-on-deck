import Foundation
import Combine
import UIKit

/// State and actions for the host-side session screen.
@MainActor
final class HostSessionViewModel: ObservableObject {
    // MARK: - Published state

    @Published var session: PhotoSession
    @Published private(set) var participants: [Participant] = []
    @Published private(set) var pendingCaptureRequests: [String] = []
    @Published private(set) var capturedPhoto: CapturedPhoto?
    @Published private(set) var transportStatus: TransportConnectionStatus = .idle
    @Published var errorMessage: String?

    // MARK: - Best-shot burst state
    @Published var burstEnabled: Bool = false
    @Published private(set) var burstCandidates: [CapturedPhoto] = []
    @Published private(set) var burstScores: [PhotoScore] = []
    @Published private(set) var isRankingBurst: Bool = false

    /// Last received reaction, surfaced as a toast for ~2.5s.
    @Published private(set) var visibleReaction: (reaction: Reaction, from: String)?
    private var reactionDismissTask: Task<Void, Never>?

    /// Fires when `session.expiresAt` arrives. Emits `.sessionEnded` to peers
    /// and lets the view dismiss back to Home.
    @Published private(set) var didExpire: Bool = false
    private var expiryTask: Task<Void, Never>?

    let camera: CameraService
    let countdown: CountdownCoordinator
    let inFrameDetector = InFrameDetector()
    let watch = WatchConnectivityBridge.shared
    private let transport: SessionTransport
    private var subs: Set<AnyCancellable> = []
    private var lastReactionLabel: String?
    private var lastReactionFrom: String?
    private var isWritingFrame = false

    // MARK: - Init

    init(hostName: String,
         allowWebJoin: Bool = false,
         camera: CameraService? = nil,
         countdown: CountdownCoordinator? = nil) {
        self.session = PhotoSession(hostName: hostName, allowWebJoin: allowWebJoin)
        self.camera = camera ?? CameraService()
        self.countdown = countdown ?? CountdownCoordinator()
        self.transport = SessionManager.makeHostTransport(
            displayName: hostName,
            allowWebJoin: allowWebJoin
        )

        participants = [
            Participant(
                id: transport.localParticipantID,
                displayName: hostName,
                role: .host,
                isReady: true,
                connectionType: SessionManager.isMockPreferred ? .mock : .nativeNearby
            )
        ]
    }

    // MARK: - Lifecycle

    func onAppear() async {
        IdentityService.shared.record(.hostSession)
        await camera.requestPermissionIfNeeded()
        camera.start()

        // Wire the camera's frame pipeline to the transport. Sendable closure;
        // hop to MainActor before touching the actor-isolated transport.
        camera.previewFrameConsumer = { [weak self] jpeg in
            Task { @MainActor in
                await self?.broadcastPreviewFrame(jpeg)
            }
        }

        do {
            try await transport.start(session: session)
        } catch {
            errorMessage = "Session konnte nicht gestartet werden."
        }

        transport.events
            .receive(on: RunLoop.main)
            .sink { [weak self] event in self?.handle(event) }
            .store(in: &subs)

        transport.connectionStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.transportStatus = status
                self?.pushWatchSnapshot()
            }
            .store(in: &subs)

        // Watch wires up here. Commands from the wrist invoke the same flows
        // as the on-screen buttons, so the watch is just a thin remote.
        watch.setCommandHandler { [weak self] cmd in
            guard let self else { return }
            switch cmd {
            case .startTimer:    Task { await self.startCountdown() }
            case .captureNow:    Task { await self.captureNow() }
            case .cancelTimer:   Task { await self.cancelCountdown() }
            case .requestSnapshot: self.pushWatchSnapshot()
            }
        }

        // Push state to the watch on every relevant change.
        $participants.sink { [weak self] _ in self?.pushWatchSnapshot() }.store(in: &subs)
        countdown.$state.sink { [weak self] _ in self?.pushWatchSnapshot() }.store(in: &subs)

        // Forward countdown and camera changes so SwiftUI re-renders host view.
        countdown.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subs)
        camera.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subs)

        pushWatchSnapshot()

        scheduleExpiry()
    }

    /// Auto-end the session when its TTL hits — privacy guarantee from the
    /// brief: ephemeral, no accounts, no lingering rooms. The relay server
    /// has its own GC; this is the iOS-side equivalent.
    private func scheduleExpiry() {
        expiryTask?.cancel()
        let delay = max(0, session.expiresAt.timeIntervalSinceNow)
        expiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                self.didExpire = true
            }
            await self.transport.send(.sessionEnded)
        }
    }

    func onDisappear() {
        expiryTask?.cancel()
        reactionDismissTask?.cancel()
        camera.previewFrameConsumer = nil
        camera.stop()
        Task { await transport.send(.sessionEnded) }
        transport.stop()
    }

    // MARK: - Settings

    func setTimerDuration(_ seconds: Int) {
        session.timerDuration = seconds
        Haptics.tap()
        Task { await transport.send(.sessionMetadata(self.session)) }
    }

    func setTriggerPermission(_ permission: TriggerPermission) {
        session.triggerPermission = permission
        Haptics.tap()
        Task { await transport.send(.sessionMetadata(self.session)) }
    }

    // MARK: - Capture flow

    func startCountdown() async {
        guard !countdown.state.isActive else { return }
        let photoAt = countdown.start(duration: session.timerDuration)
        await transport.send(.countdownStarted(
            photoAt: photoAt,
            duration: session.timerDuration,
            startedBy: transport.localParticipantID
        ))
        Haptics.thump()

        let delay = max(0, photoAt.timeIntervalSinceNow)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        if case .idle = countdown.state { return }
        await capture()
    }

    func cancelCountdown() async {
        countdown.cancel()
        await transport.send(.countdownCancelled(by: transport.localParticipantID))
    }

    func captureNow() async {
        if countdown.state.isActive { countdown.cancel() }
        await capture()
    }

    private func capture() async {
        countdown.markCapturing()
        if burstEnabled {
            await captureBurst()
        } else {
            await captureSingle()
        }
    }

    private func captureSingle() async {
        do {
            let data = try await camera.capturePhoto()
            let photo = CapturedPhoto(imageData: data)
            self.capturedPhoto = photo
            countdown.markCompleted()
            IdentityService.shared.record(.capturePhoto)
            await transport.send(.photoCaptured(at: photo.capturedAt))
            let preview = ImageCompression.scaledJPEG(data: data, maxWidth: 1280, quality: 0.7)
            await transport.send(.finalPhotoAvailable(photoID: photo.id, jpeg: preview))
            Haptics.success()
        } catch {
            errorMessage = "Foto konnte nicht aufgenommen werden."
            countdown.cancel()
        }
    }

    private func captureBurst() async {
        let blobs = await camera.captureBurst(count: 5, delay: 0.35)
        guard !blobs.isEmpty else {
            errorMessage = "Burst fehlgeschlagen."
            countdown.cancel()
            return
        }
        countdown.markCompleted()
        burstCandidates = blobs.map { CapturedPhoto(imageData: $0) }
        Haptics.success()
        await transport.send(.photoCaptured(at: Date()))

        // Score in the background; the user already sees the candidates and
        // can pick manually if they don't want to wait. We deliberately do
        // **not** auto-broadcast the top-ranked candidate — viewers would
        // briefly see one shot, then a different one when the captain picks.
        // Only `acceptBurstPick` broadcasts the final selection.
        isRankingBurst = true
        burstScores = await PhotoQualityScorer.rank(blobs)
        isRankingBurst = false
    }

    /// Captain confirms a burst pick — promote it to the canonical capture.
    func acceptBurstPick(_ photo: CapturedPhoto) async {
        capturedPhoto = photo
        burstCandidates = []
        burstScores = []
        IdentityService.shared.record(.acceptBurst)
        let preview = ImageCompression.scaledJPEG(
            data: photo.imageData, maxWidth: 1280, quality: 0.7
        )
        await transport.send(.finalPhotoAvailable(photoID: photo.id, jpeg: preview))
    }

    func discardBurst() {
        burstCandidates = []
        burstScores = []
        countdown.cancel()
    }

    func discardCapture() {
        capturedPhoto = nil
        countdown.cancel()
    }

    // MARK: - Capture-request approval

    func approve(participantID: String) async {
        pendingCaptureRequests.removeAll { $0 == participantID }
        await transport.send(.captureApproved(approvedBy: transport.localParticipantID))
        await startCountdown()
    }

    func deny(participantID: String) async {
        pendingCaptureRequests.removeAll { $0 == participantID }
        await transport.send(.captureDenied(deniedBy: transport.localParticipantID))
    }

    // MARK: - Frame broadcast

    private func broadcastPreviewFrame(_ jpeg: Data) async {
        // Always run vision on whatever we have — the host sees the hint chip
        // even before any viewer is connected.
        inFrameDetector.ingest(jpeg: jpeg)

        // Broadcast once a Multipeer viewer is present, or always when web-join
        // is enabled (web viewers may join before their participantJoined arrives).
        guard participants.count > 1 || session.allowWebJoin else { return }
        guard !isWritingFrame else { return }
        isWritingFrame = true
        await transport.send(.previewFrame(jpeg: jpeg, capturedAt: Date()))
        isWritingFrame = false
    }

    // MARK: - Inbound events

    private func handle(_ event: SessionEvent) {
        switch event {
        case .participantJoined(let p):
            if !participants.contains(where: { $0.id == p.id }) {
                participants.append(p)
                Haptics.tap()
            }
            Task { await transport.send(.sessionMetadata(self.session)) }

        case .participantLeft(let id):
            // Multipeer transport reports leaves with peerID.displayName,
            // mock transport reports them with the local participant UUID.
            // Match either to avoid ghost entries.
            participants.removeAll { $0.id == id || $0.displayName == id }

        case .participantReadyChanged(let id, let ready):
            if let idx = participants.firstIndex(where: { $0.id == id }) {
                participants[idx].isReady = ready
            }

        case .reactionSent(let by, let reactionRaw):
            guard let reaction = Reaction(rawValue: reactionRaw) else { break }
            let displayName = participants.first { $0.id == by }?.displayName ?? "Crew"
            visibleReaction = (reaction, displayName)
            lastReactionLabel = reaction.label
            lastReactionFrom = displayName
            pushWatchSnapshot()
            reactionDismissTask?.cancel()
            reactionDismissTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.visibleReaction = nil
                    // Also clear it on the watch snapshot so the wrist UI
                    // doesn't keep displaying a stale "Bereit" forever.
                    self?.lastReactionLabel = nil
                    self?.lastReactionFrom = nil
                    self?.pushWatchSnapshot()
                }
            }
            // Haptic louder for framing hints (camera-move suggestions).
            if reaction.isFramingHint { Haptics.warning() } else { Haptics.tick() }

        case .captureRequested(let by):
            switch session.triggerPermission {
            case .everyoneCanStartTimer:
                Task { await startCountdown() }
            case .viewersCanRequest:
                if !pendingCaptureRequests.contains(by) {
                    pendingCaptureRequests.append(by)
                    Haptics.warning()
                }
            case .hostOnly:
                break
            }

        default:
            break
        }
    }

    // MARK: - Helpers

    var localID: String { transport.localParticipantID }
    var qrPayload: String { session.joinURL.absoluteString }

    // MARK: - Watch snapshot

    private func pushWatchSnapshot() {
        let countdownState: WatchSnapshot.CountdownState
        var photoAt: Double?
        switch countdown.state {
        case .idle:       countdownState = .idle
        case .running(let date, _):
            countdownState = .running
            photoAt = date.timeIntervalSince1970 * 1000
        case .capturing:  countdownState = .capturing
        case .completed:  countdownState = .completed
        }
        let snap = WatchSnapshot(
            sessionID: session.id,
            hostName: session.hostName,
            participantCount: participants.count,
            timerDuration: session.timerDuration,
            canTrigger: !countdown.state.isActive,
            countdown: countdownState,
            photoAtEpochMs: photoAt,
            lastReactionLabel: lastReactionLabel,
            lastReactionFrom: lastReactionFrom,
            generatedAt: Date()
        )
        watch.push(snapshot: snap)
    }

    /// Human-friendly status string for the LIVE pill in the UI.
    var statusLabel: String {
        switch transportStatus {
        case .idle:         return "BEREIT"
        case .advertising:  return "LIVE"
        case .browsing, .connecting: return "VERBINDE"
        case .connected:    return "LIVE"
        case .disconnected: return "OFFLINE"
        case .notFound:     return "OFFLINE"
        case .failed:       return "FEHLER"
        }
    }
}
