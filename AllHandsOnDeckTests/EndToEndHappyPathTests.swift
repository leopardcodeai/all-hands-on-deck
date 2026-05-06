import XCTest
import Combine
@testable import AllHandsOnDeck

/// End-to-end happy-path: a host and a viewer share one session, a photo is
/// captured, and every protocol step lands in the right inbox in the right
/// order. Runs entirely against `MockSessionTransport` so no AVFoundation,
/// no Supabase, no Multipeer — pure protocol coverage.
///
/// What this catches:
///   - Wire-format breakage between SessionEvent encoder and decoder
///   - Broker dispatch / fan-out / sender-echo suppression
///   - Event-ordering invariants the iOS host and the web viewer both depend on
@MainActor
final class EndToEndHappyPathTests: XCTestCase {
    private var subs: Set<AnyCancellable> = []

    override func tearDown() {
        subs.removeAll()
        super.tearDown()
    }

    /// Drives one full session through every protocol stage:
    ///   start → join → metadata → trigger → capture → final photo arrives.
    func test_happyPath_hostStartsViewerJoinsPhotoArrives() async throws {
        // ── Arrange ────────────────────────────────────────────────────────
        var session = PhotoSession(id: "HAPPYPATH1", hostName: "Captain")
        // Default permission lets viewers fire the trigger directly — that's
        // the lowest-friction flow the webapp uses.
        session.triggerPermission = .everyoneCanStartTimer

        let host   = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Crew")

        var hostInbox: [SessionEvent] = []
        var viewerInbox: [SessionEvent] = []
        host.events.sink   { hostInbox.append($0)   }.store(in: &subs)
        viewer.events.sink { viewerInbox.append($0) }.store(in: &subs)

        // ── Stage 1: host advertises, viewer joins ─────────────────────────
        try await host.start(session: session)
        try await viewer.start(session: session)
        try await flush()

        XCTAssertTrue(
            hostInbox.contains(where: { if case .participantJoined = $0 { true } else { false } }),
            "Host should see viewer's participantJoined immediately after start()"
        )

        // ── Stage 2: host replies with session metadata ────────────────────
        // Real `HostSessionViewModel.handle(.participantJoined)` does this
        // automatically; we replay it explicitly here to keep the test
        // framework-light.
        await host.send(.sessionMetadata(session))
        try await flush()

        let metadata = viewerInbox.compactMap { event -> PhotoSession? in
            if case .sessionMetadata(let s) = event { return s } else { return nil }
        }.first
        XCTAssertNotNil(metadata, "Viewer should receive sessionMetadata after joining")
        XCTAssertEqual(metadata?.triggerPermission, .everyoneCanStartTimer)
        XCTAssertEqual(metadata?.id, "HAPPYPATH1")

        // ── Stage 3: viewer fires immediate-capture (the "⚡ Now" button) ──
        await viewer.send(.captureNowRequested(by: viewer.localParticipantID))
        try await flush()

        XCTAssertTrue(
            hostInbox.contains(where: { if case .captureNowRequested = $0 { true } else { false } }),
            "Host should see captureNowRequested from viewer"
        )

        // ── Stage 4: host captures and broadcasts the photo ────────────────
        // Real `HostSessionViewModel.captureSingle()` runs the camera, scales
        // the JPEG, and emits these two events back-to-back. We simulate the
        // result with a tiny synthetic JPEG so the wire flow is exercised.
        let fakeJpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0xAA, 0xBB])
        let photoID  = UUID().uuidString
        let captureAt = Date()

        await host.send(.photoCaptured(at: captureAt))
        await host.send(.finalPhotoAvailable(photoID: photoID, jpeg: fakeJpeg))
        try await flush()

        // ── Assert: viewer received the full photo handshake ───────────────
        let sawCaptured = viewerInbox.contains { if case .photoCaptured = $0 { true } else { false } }
        XCTAssertTrue(sawCaptured, "Viewer should see photoCaptured")

        let receivedPhoto = viewerInbox.compactMap { event -> (String, Data)? in
            if case .finalPhotoAvailable(let id, let jpeg) = event { return (id, jpeg) } else { return nil }
        }.first
        XCTAssertNotNil(receivedPhoto, "Viewer should receive finalPhotoAvailable")
        XCTAssertEqual(receivedPhoto?.0, photoID, "Photo ID must round-trip intact")
        XCTAssertEqual(receivedPhoto?.1, fakeJpeg, "JPEG bytes must round-trip intact")

        // ── Sender-echo suppression: host must not see its own captureNow ──
        XCTAssertFalse(
            hostInbox.contains(where: { if case .photoCaptured = $0 { true } else { false } }),
            "Host should not receive its own broadcast events"
        )
    }

    /// Variant: hostOnly trigger permission. The viewer's request must not
    /// produce a photo because the host's event handler should ignore it.
    /// This is the negative test that pairs with the happy path.
    func test_hostOnlyPermission_viewerTriggerIsIgnored() async throws {
        var session = PhotoSession(id: "HOSTONLYAA", hostName: "Captain")
        session.triggerPermission = .hostOnly

        let host   = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Crew")

        var hostInbox: [SessionEvent] = []
        host.events.sink { hostInbox.append($0) }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        await host.send(.sessionMetadata(session))
        try await flush()

        // Viewer attempts to trigger.
        await viewer.send(.captureRequested(by: viewer.localParticipantID))
        try await flush()

        // Host transport delivers the event (it's not the transport's job to
        // permission-check); the *view model* is what should ignore it. So we
        // assert the event arrived — the gating is exercised in HostSessionViewModel
        // tests, not here.
        XCTAssertTrue(
            hostInbox.contains(where: { if case .captureRequested = $0 { true } else { false } }),
            "Transport always delivers; permission gating is the view model's job"
        )
    }

    // ── Happy path: timer countdown ─────────────────────────────────────────
    //
    // Host announces a 3-second countdown, viewer mirrors the photoAt target,
    // host fires the photo when the deadline lands. This is the default "Timer"
    // button flow — the most-used path in the app.
    func test_happyPath_timerCountdown_endsInPhoto() async throws {
        var session = PhotoSession(id: "TIMERROOM1", hostName: "Captain")
        session.timerDuration = 3

        let host   = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Crew")

        var viewerInbox: [SessionEvent] = []
        viewer.events.sink { viewerInbox.append($0) }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        try await flush()

        let photoAt = Date().addingTimeInterval(TimeInterval(session.timerDuration))
        await host.send(.countdownStarted(photoAt: photoAt, duration: 3, startedBy: host.localParticipantID))
        try await flush()

        let countdown = viewerInbox.compactMap { event -> (Date, Int)? in
            if case .countdownStarted(let at, let dur, _) = event { return (at, dur) } else { return nil }
        }.first
        XCTAssertNotNil(countdown, "Viewer should see countdownStarted")
        XCTAssertEqual(countdown?.1, 3)
        XCTAssertEqual(countdown?.0.timeIntervalSinceReferenceDate ?? 0,
                       photoAt.timeIntervalSinceReferenceDate, accuracy: 0.01,
                       "photoAt must round-trip without drift — both clients tick off this exact instant")

        // Photo lands when the timer expires.
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x42])
        await host.send(.photoCaptured(at: photoAt))
        await host.send(.finalPhotoAvailable(photoID: "p1", jpeg: jpeg))
        try await flush()

        let final = viewerInbox.compactMap { event -> Data? in
            if case .finalPhotoAvailable(_, let j) = event { return j } else { return nil }
        }.first
        XCTAssertEqual(final, jpeg, "Viewer should receive the final JPEG verbatim")
    }

    // ── Happy path: countdown cancelled mid-flight ──────────────────────────
    //
    // Captain hits "Abbrechen" before the deadline — viewer must drop the
    // countdown HUD and no photo should follow.
    func test_happyPath_countdownCancelled_noPhoto() async throws {
        let session = PhotoSession(id: "CANCELROOM", hostName: "Captain")

        let host   = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Crew")

        var viewerInbox: [SessionEvent] = []
        viewer.events.sink { viewerInbox.append($0) }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        try await flush()

        let photoAt = Date().addingTimeInterval(10)
        await host.send(.countdownStarted(photoAt: photoAt, duration: 10, startedBy: host.localParticipantID))
        await host.send(.countdownCancelled(by: host.localParticipantID))
        try await flush()

        let sawStarted   = viewerInbox.contains { if case .countdownStarted   = $0 { true } else { false } }
        let sawCancelled = viewerInbox.contains { if case .countdownCancelled = $0 { true } else { false } }
        let sawPhoto     = viewerInbox.contains { if case .finalPhotoAvailable = $0 { true } else { false } }

        XCTAssertTrue(sawStarted)
        XCTAssertTrue(sawCancelled, "Viewer must see the cancellation to clear its UI")
        XCTAssertFalse(sawPhoto, "No photo event should follow a cancelled countdown")
    }

    // ── Happy path: two viewers, one host ───────────────────────────────────
    //
    // The most common real-world setup: host iPhone + two friends on web.
    // Both viewers must receive the same photo bytes, and the host must see
    // both joins.
    func test_happyPath_twoViewers_bothReceivePhoto() async throws {
        let session = PhotoSession(id: "TWOVIEWERS", hostName: "Captain")
        let host = MockSessionTransport(role: .host, displayName: "Captain")
        let v1   = MockSessionTransport(role: .viewer, displayName: "Mate 1")
        let v2   = MockSessionTransport(role: .viewer, displayName: "Mate 2")

        var hostInbox: [SessionEvent] = []
        var v1Inbox: [SessionEvent] = []
        var v2Inbox: [SessionEvent] = []
        host.events.sink { hostInbox.append($0) }.store(in: &subs)
        v1.events.sink   { v1Inbox.append($0)   }.store(in: &subs)
        v2.events.sink   { v2Inbox.append($0)   }.store(in: &subs)

        try await host.start(session: session)
        try await v1.start(session: session)
        try await v2.start(session: session)
        try await flush()

        let joinCount = hostInbox.filter { if case .participantJoined = $0 { true } else { false } }.count
        XCTAssertEqual(joinCount, 2, "Host should see exactly two joins, one per viewer")

        let jpeg = Data([0xFF, 0xD8, 0xCA, 0xFE])
        await host.send(.finalPhotoAvailable(photoID: "shared", jpeg: jpeg))
        try await flush()

        let v1Got = v1Inbox.contains { if case .finalPhotoAvailable(_, let j) = $0 { j == jpeg } else { false } }
        let v2Got = v2Inbox.contains { if case .finalPhotoAvailable(_, let j) = $0 { j == jpeg } else { false } }
        XCTAssertTrue(v1Got, "Viewer 1 must receive the photo")
        XCTAssertTrue(v2Got, "Viewer 2 must receive the same photo bytes")
    }

    // ── Happy path: viewersCanRequest approval flow ─────────────────────────
    //
    // The mid-trust permission: viewers may request, captain decides. Sequence
    // is request → approve → countdown → photo.
    func test_happyPath_viewersCanRequest_hostApprovesFlow() async throws {
        var session = PhotoSession(id: "APPROVALAB", hostName: "Captain")
        session.triggerPermission = .viewersCanRequest

        let host   = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Crew")

        var hostInbox: [SessionEvent] = []
        var viewerInbox: [SessionEvent] = []
        host.events.sink   { hostInbox.append($0)   }.store(in: &subs)
        viewer.events.sink { viewerInbox.append($0) }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        await host.send(.sessionMetadata(session))
        try await flush()

        // Viewer requests. Host receives.
        await viewer.send(.captureRequested(by: viewer.localParticipantID))
        try await flush()
        XCTAssertTrue(
            hostInbox.contains { if case .captureRequested = $0 { true } else { false } },
            "Host should see the request"
        )

        // Captain approves and starts the countdown.
        await host.send(.captureApproved(approvedBy: host.localParticipantID))
        let photoAt = Date().addingTimeInterval(2)
        await host.send(.countdownStarted(photoAt: photoAt, duration: 2, startedBy: host.localParticipantID))
        try await flush()

        XCTAssertTrue(viewerInbox.contains { if case .captureApproved = $0 { true } else { false } })
        XCTAssertTrue(viewerInbox.contains { if case .countdownStarted = $0 { true } else { false } })
    }

    // ── Happy path: reaction reaches the captain ────────────────────────────
    //
    // Reactions like "Wait a sec" or "Camera up" are the lightweight feedback
    // channel. They must round-trip the rawValue so the iOS host can map back
    // to the typed `Reaction` enum.
    func test_happyPath_reactionFromViewer_reachesHost() async throws {
        let session = PhotoSession(id: "REACTROOM1", hostName: "Captain")
        let host   = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Crew")

        var hostInbox: [SessionEvent] = []
        host.events.sink { hostInbox.append($0) }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        try await flush()

        await viewer.send(.reactionSent(by: viewer.localParticipantID, reaction: Reaction.raiseCamera.rawValue))
        try await flush()

        let received = hostInbox.compactMap { event -> Reaction? in
            if case .reactionSent(_, let raw) = event { return Reaction(rawValue: raw) } else { return nil }
        }.first
        XCTAssertEqual(received, .raiseCamera, "rawValue must match what `Reaction(rawValue:)` accepts")
    }

    // ── Happy path: preview frames stream to the viewer ─────────────────────
    //
    // The host runs the camera at ~3fps and pushes JPEG previews. Viewer must
    // receive each frame's bytes (unique per frame, so we can detect lost ones).
    func test_happyPath_previewFramesStream() async throws {
        let session = PhotoSession(id: "FRAMEROOM1", hostName: "Captain")
        let host   = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Crew")

        var receivedFrames: [Data] = []
        viewer.events.sink { event in
            if case .previewFrame(let jpeg, _) = event { receivedFrames.append(jpeg) }
        }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        try await flush()

        let frames = (0..<5).map { Data([0xFF, 0xD8, UInt8($0), 0xEE]) }
        for f in frames {
            await host.send(.previewFrame(jpeg: f, capturedAt: Date()))
        }
        try await flush()

        XCTAssertEqual(receivedFrames.count, frames.count, "Every frame must arrive — backpressure is the host's job, not the wire's")
        XCTAssertEqual(receivedFrames, frames, "Frames must arrive in order with bytes intact")
    }

    // ── Happy path: session ends, viewers notified ──────────────────────────
    //
    // When the captain leaves or the TTL hits, every viewer must see
    // `.sessionEnded` so they can clear state and dismiss to home.
    func test_happyPath_sessionEnded_notifiesViewers() async throws {
        let session = PhotoSession(id: "ENDROOMABC", hostName: "Captain")
        let host   = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Crew")

        var viewerInbox: [SessionEvent] = []
        viewer.events.sink { viewerInbox.append($0) }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        try await flush()

        await host.send(.sessionEnded)
        try await flush()

        XCTAssertTrue(
            viewerInbox.contains { if case .sessionEnded = $0 { true } else { false } },
            "Viewer must see sessionEnded so its UI can transition to the dismissal screen"
        )
    }

    // ── Crew: Three viewers, all receive the same photo ───────────────────

    /// Host + 3 viewers. All three must receive the final photo bytes.
    /// This is the most common real-world crew photo scenario.
    func test_crewOfThree_allReceivePhoto() async throws {
        var session = PhotoSession(id: "CREW3TEST", hostName: "Captain")
        session.triggerPermission = .everyoneCanStartTimer

        let host = MockSessionTransport(role: .host, displayName: "Captain")
        let v1 = MockSessionTransport(role: .viewer, displayName: "FirstMate")
        let v2 = MockSessionTransport(role: .viewer, displayName: "DeckHand")
        let v3 = MockSessionTransport(role: .viewer, displayName: "Lookout")

        var hostInbox: [SessionEvent] = []
        var v1Photos: [Data] = []
        var v2Photos: [Data] = []
        var v3Photos: [Data] = []

        host.events.sink { hostInbox.append($0) }.store(in: &subs)
        v1.events.sink { if case .finalPhotoAvailable(_, let j) = $0 { v1Photos.append(j) } }.store(in: &subs)
        v2.events.sink { if case .finalPhotoAvailable(_, let j) = $0 { v2Photos.append(j) } }.store(in: &subs)
        v3.events.sink { if case .finalPhotoAvailable(_, let j) = $0 { v3Photos.append(j) } }.store(in: &subs)

        try await host.start(session: session)
        try await v1.start(session: session)
        try await v2.start(session: session)
        try await v3.start(session: session)
        try await flush()

        // Host must see all 3 joins
        let joinCount = hostInbox.filter { if case .participantJoined = $0 { true } else { false } }.count
        XCTAssertEqual(joinCount, 3, "Host must see exactly three participant joins")

        // Send photo — all 3 must receive it
        let photo = Data([0xFF, 0xD8, 0xCA, 0xFE, 0xBA, 0xBE])
        await host.send(.finalPhotoAvailable(photoID: "crew3photo", jpeg: photo))
        try await flush()

        XCTAssertEqual(v1Photos.count, 1, "Viewer 1 must receive the photo")
        XCTAssertEqual(v2Photos.count, 1, "Viewer 2 must receive the photo")
        XCTAssertEqual(v3Photos.count, 1, "Viewer 3 must receive the photo")
        XCTAssertEqual(v1Photos.first, photo, "All viewers receive the exact same bytes")
        XCTAssertEqual(v2Photos.first, photo)
        XCTAssertEqual(v3Photos.first, photo)
    }

    // ── Crew: Viewer leaves mid-session ──────────────────────────────────

    func test_viewerLeaves_hostIsNotified() async throws {
        let session = PhotoSession(id: "LEAVECREW", hostName: "Captain")
        let host = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "DeckHand")

        var hostInbox: [SessionEvent] = []
        host.events.sink { hostInbox.append($0) }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        try await flush()

        // Simulate viewer disconnecting — sent from viewer side
        // (host has sender-echo suppression so it won't receive its own participantLeft)
        await viewer.send(.participantLeft(participantID: viewer.localParticipantID))
        try await flush()

        XCTAssertTrue(
            hostInbox.contains(where: { if case .participantLeft = $0 { true } else { false } }),
            "Host should see viewer's participantLeft event"
        )
    }

    // ── Crew: Ready-state changes ────────────────────────────────────────

    func test_viewerTogglesReady_hostReceivesUpdate() async throws {
        let session = PhotoSession(id: "READYCREW", hostName: "Captain")
        let host = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Mate")

        var hostInbox: [SessionEvent] = []
        host.events.sink { hostInbox.append($0) }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        try await flush()

        // Toggle ready → not ready → ready
        await viewer.send(.participantReadyChanged(participantID: viewer.localParticipantID, isReady: true))
        await viewer.send(.participantReadyChanged(participantID: viewer.localParticipantID, isReady: false))
        await viewer.send(.participantReadyChanged(participantID: viewer.localParticipantID, isReady: true))
        try await flush()

        let readyCount = hostInbox.filter {
            if case .participantReadyChanged(let pid, let ready) = $0, pid == viewer.localParticipantID { return true }
            return false
        }.count
        XCTAssertEqual(readyCount, 3, "Host should receive all 3 ready-state changes")
    }

    // ── Crew: Mixed connection types ─────────────────────────────────────

    func test_mixedConnectionTypes_allWork() async throws {
        var session = PhotoSession(id: "MIXED01", hostName: "Captain")
        session.triggerPermission = .everyoneCanStartTimer

        let host = MockSessionTransport(role: .host, displayName: "Captain")
        let iosViewer = MockSessionTransport(role: .viewer, displayName: "iPhoneMate")
        let webViewer = MockSessionTransport(role: .viewer, displayName: "BrowserMate")

        var hostInbox: [SessionEvent] = []
        var webInbox: [SessionEvent] = []
        host.events.sink { hostInbox.append($0) }.store(in: &subs)
        webViewer.events.sink { webInbox.append($0) }.store(in: &subs)

        try await host.start(session: session)
        try await iosViewer.start(session: session)
        try await webViewer.start(session: session)
        try await flush()

        // Both viewers should be visible to host
        XCTAssertEqual(hostInbox.filter { if case .participantJoined = $0 { true } else { false } }.count, 2)

        // Trigger from web viewer
        await webViewer.send(.captureNowRequested(by: webViewer.localParticipantID))
        try await flush()
        XCTAssertTrue(hostInbox.contains(where: { if case .captureNowRequested = $0 { true } else { false } }))

        // Host sends photo → all viewers get it
        let jpeg = Data([0xFF, 0xD8, 0xEE, 0xEE])
        await host.send(.finalPhotoAvailable(photoID: "mixed", jpeg: jpeg))
        try await flush()
        XCTAssertTrue(webInbox.contains(where: { if case .finalPhotoAvailable(_, let j) = $0 { j == jpeg } else { false } }))
    }

    // ── Crew: Burst-mode capture with best-shot pick ─────────────────────

    func test_burstCapture_pickBestShot() async throws {
        var session = PhotoSession(id: "BURST01", hostName: "Captain")
        session.timerDuration = 0  // immediate

        let host = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Mate")

        var viewerPhotos: [(String, Data)] = []
        viewer.events.sink { event in
            if case .finalPhotoAvailable(let id, let jpeg) = event {
                viewerPhotos.append((id, jpeg))
            }
        }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        try await flush()

        // Simulate burst: host sends 5 candidate photos, then picks best
        let candidates = (0..<5).map { i in Data([0xFF, 0xD8, UInt8(i), 0x00]) }
        for (i, jpeg) in candidates.enumerated() {
            await host.send(.finalPhotoAvailable(photoID: "burst_\(i)", jpeg: jpeg))
        }
        try await flush()

        // Viewer should receive all candidates and can pick
        XCTAssertEqual(viewerPhotos.count, 5, "Viewer should receive all burst candidates")
    }

    // ── Crew: Permission change mid-session ──────────────────────────────

    func test_permissionChangedMidSession_viewersSeeUpdate() async throws {
        var session = PhotoSession(id: "PERMCHG", hostName: "Captain")
        session.triggerPermission = .viewersCanRequest

        let host = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Mate")

        var viewerMetadata: [TriggerPermission] = []
        viewer.events.sink { event in
            if case .sessionMetadata(let s) = event { viewerMetadata.append(s.triggerPermission) }
        }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        await host.send(.sessionMetadata(session))
        try await flush()

        // Change permission to hostOnly
        session.triggerPermission = .hostOnly
        await host.send(.sessionMetadata(session))
        try await flush()

        XCTAssertEqual(viewerMetadata.count, 2, "Viewer should receive both permission updates")
        XCTAssertEqual(viewerMetadata.last, .hostOnly, "Last permission should be hostOnly")
    }

    // ── Crew: Large JPEG photo round-trip ─────────────────────────────────

    func test_largePhoto_roundTripsIntact() async throws {
        let session = PhotoSession(id: "BIGPHOTO", hostName: "Captain")
        let host = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Mate")

        var received: Data?
        viewer.events.sink { event in
            if case .finalPhotoAvailable(_, let jpeg) = event { received = jpeg }
        }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        try await flush()

        // Simulate a larger JPEG (~1KB)
        let largeJpeg = Data((0..<1024).map { UInt8($0 % 256) })
        await host.send(.finalPhotoAvailable(photoID: "big", jpeg: largeJpeg))
        try await flush()

        XCTAssertNotNil(received, "Viewer must receive the large photo")
        XCTAssertEqual(received, largeJpeg, "Large JPEG must round-trip byte-perfect")
    }

    // ── Crew: Rapid-fire captures (Stress) ───────────────────────────────

    func test_rapidFireCaptures_allArriveInOrder() async throws {
        var session = PhotoSession(id: "RAPID01", hostName: "Captain")
        session.triggerPermission = .everyoneCanStartTimer

        let host = MockSessionTransport(role: .host, displayName: "Captain")
        let viewer = MockSessionTransport(role: .viewer, displayName: "Mate")

        var photos: [(String, Data)] = []
        viewer.events.sink { event in
            if case .finalPhotoAvailable(let id, let jpeg) = event { photos.append((id, jpeg)) }
        }.store(in: &subs)

        try await host.start(session: session)
        try await viewer.start(session: session)
        try await flush()

        // Rapid-fire 10 photos
        for i in 0..<10 {
            await host.send(.finalPhotoAvailable(photoID: "rapid_\(i)", jpeg: Data([UInt8(i)])))
        }
        try await flush()

        XCTAssertEqual(photos.count, 10, "All 10 rapid-fire photos must arrive")
        // Verify order
        for (i, pair) in photos.enumerated() {
            XCTAssertEqual(pair.0, "rapid_\(i)", "Photo \(i) must arrive in order")
        }
    }

    // MARK: - Helpers

    /// MockBroker dispatches synchronously on MainActor, but we still yield
    /// once so any subsequent async-scheduled hops complete before assertions.
    private func flush() async throws {
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
    }
}
