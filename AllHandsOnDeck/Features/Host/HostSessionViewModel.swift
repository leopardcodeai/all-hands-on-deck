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
    private var mockFrameTask: Task<Void, Never>?

    let camera: CameraService
    let countdown: CountdownCoordinator
    let inFrameDetector = InFrameDetector()
    let watch = WatchConnectivityBridge.shared
    private let transport: SessionTransport
    private var subs: Set<AnyCancellable> = []
    private var lastReactionLabel: String?
    private var lastReactionFrom: String?
    private var isWritingFrame = false
    private let watchTrigger = PassthroughSubject<Void, Never>()
    private var isStarted = false

    // MARK: - Init

    init(hostName: String,
         allowWebJoin: Bool = false,
         camera: CameraService? = nil,
         countdown: CountdownCoordinator? = nil) {
        let sessionID = PhotoSession.makeShortID()
        self.session = PhotoSession(
            id: sessionID,
            hostName: hostName,
            ttlMinutes: SessionPolicy.mvp.maxSessionDurationMinutes,
            allowWebJoin: allowWebJoin,
            joinToken: JoinToken(sessionID: sessionID)
        )
        self.camera = camera ?? CameraService()
        self.countdown = countdown ?? CountdownCoordinator()
        self.transport = SessionManager.makeHostTransport(
            displayName: hostName,
            allowWebJoin: allowWebJoin
        )

        let hostParticipant = Participant(
            id: transport.localParticipantID,
            displayName: hostName,
            role: .host,
            isReady: true,
            connectionType: SessionManager.isMockPreferred ? .mock : .nativeNearby
        )
        participants = [hostParticipant]
        session.participants = [hostParticipant]

        // Start the capture session immediately if already authorized — it runs on
        // sessionQueue so this returns instantly. By the time the navigation push
        // animation completes (~0.35s) the session is live and the preview is ready.
        if self.camera.authorization == .authorized {
            self.camera.start()
        }
    }

    // MARK: - Lifecycle

    func onAppear() async {
        // Idempotent: HostSessionRetention may resume a parked VM, in which
        // case the transport, camera, and Combine subs are already wired.
        guard !isStarted else { return }
        isStarted = true

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

        // In mock mode, generate synthetic preview frames since the
        // simulator camera doesn't produce real ones. Start AFTER the
        // transport so broadcastPreviewFrame has a connected channel.
        if SessionManager.isMockPreferred {
            startMockFrameStream()
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

        // Push state to the watch — throttled so a live countdown doesn't flood WCSession.
        $participants.sink { [weak self] _ in self?.watchTrigger.send() }.store(in: &subs)
        countdown.$state.sink { [weak self] _ in self?.watchTrigger.send() }.store(in: &subs)
        watchTrigger
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.pushWatchSnapshot() }
            .store(in: &subs)

        // Forward countdown changes so SwiftUI re-renders host view.
        // Camera changes are handled by @ObservedObject sub-views in HostSessionView.
        countdown.objectWillChange
            .receive(on: DispatchQueue.main)
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

    // MARK: - Mock frame stream

    /// Generates synthetic preview frames at ~3 fps when the simulator camera
    /// doesn't produce real frames. Only active in DEBUG + mock mode.
    private func startMockFrameStream() {
        mockFrameTask = Task { [weak self] in
            let imageSize = CGSize(width: 640, height: 480)
            let renderer = UIGraphicsImageRenderer(size: imageSize)
            var hue: CGFloat = 0

            while !Task.isCancelled {
                guard let host = self else { break }
                hue = hue.truncatingRemainder(dividingBy: 1.0) + 0.03
                let tint = UIColor(hue: hue, saturation: 0.6, brightness: 0.9, alpha: 1)

                let jpeg = renderer.jpegData(withCompressionQuality: 0.7) { ctx in
                    let rect = CGRect(origin: .zero, size: imageSize)
                    tint.setFill()
                    ctx.fill(rect)
                    let label = NSString(string: "Crew Preview LIVE")
                    label.draw(at: CGPoint(x: 160, y: 200),
                               withAttributes: [
                                .foregroundColor: UIColor.black,
                                .font: UIFont.boldSystemFont(ofSize: 32)
                               ])
                }

                await host.broadcastPreviewFrame(jpeg)
                try? await Task.sleep(nanoseconds: 330_000_000)
            }
        }
    }
    /// Called either by `HostSessionRetention` after the 10s park window or
    /// directly when the session expires.
    func shutdown() {
        guard isStarted else { return }
        isStarted = false
        expiryTask?.cancel()
        mockFrameTask?.cancel()
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
        let photoAt = Date().addingTimeInterval(TimeInterval(session.timerDuration))
        // Send BEFORE arming local countdown so viewers see it as early as possible.
        await transport.send(.countdownStarted(
            photoAt: photoAt,
            duration: session.timerDuration,
            startedBy: transport.localParticipantID
        ))
        countdown.armRunning(photoAt: photoAt, duration: session.timerDuration)
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
            let preview = await Task.detached(priority: .userInitiated) {
                ImageCompression.scaledJPEG(data: data, maxWidth: 1280, quality: 0.7)
            }.value
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
        // Clear any existing final photo so webapp doesn't show stale overlay
        await transport.send(.countdownCancelled(by: transport.localParticipantID))
        capturedPhoto = photo
        burstCandidates = []
        burstScores = []
        IdentityService.shared.record(.acceptBurst)
        let imageData = photo.imageData
        let preview = await Task.detached(priority: .userInitiated) {
            ImageCompression.scaledJPEG(data: imageData, maxWidth: 1280, quality: 0.7)
        }.value
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

        // Broadcast whenever the transport has a connected peer (covers the
        // Multipeer race where transportStatus goes .connected before the
        // viewer's participantJoined message arrives), or always when web-join
        // is enabled (web viewers may join before their participantJoined arrives).
        guard participants.count > 1 || transportStatus == .connected || session.allowWebJoin else { return }
        guard !isWritingFrame else { return }
        isWritingFrame = true
        await transport.send(.previewFrame(jpeg: jpeg, capturedAt: Date()))
        isWritingFrame = false
    }

    // MARK: - Inbound events

    /// Internal so tests can drive permission gating without standing up the
    /// full Combine + camera pipeline that `onAppear()` wires.
    func handle(_ event: SessionEvent) {
        switch event {
        case .participantJoined(let p):
            if !participants.contains(where: { $0.id == p.id }) {
                participants.append(p)
                session.participants = participants
                Haptics.tap()
            }
            Task { await transport.send(.sessionMetadata(self.session)) }

        case .participantLeft(let id):
            // Multipeer transport reports leaves with peerID.displayName,
            // mock transport reports them with the local participant UUID.
            // Match either to avoid ghost entries.
            participants.removeAll { $0.id == id || $0.displayName == id }
            session.participants = participants

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

        case .captureNowRequested:
            if session.triggerPermission == .everyoneCanStartTimer {
                Task { await captureNow() }
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
        case .idle:         return DesignLabels.statusReady
        case .advertising:  return DesignLabels.statusLive
        case .browsing, .connecting: return DesignLabels.statusConnecting
        case .connected:    return DesignLabels.statusLive
        case .disconnected: return DesignLabels.statusOffline
        case .notFound:     return DesignLabels.statusOffline
        case .failed:       return DesignLabels.statusError
        }
    }
}
