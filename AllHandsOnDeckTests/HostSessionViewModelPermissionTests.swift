import XCTest
@testable import AllHandsOnDeck

/// Permission-gating tests for `HostSessionViewModel.handle(_:)`.
///
/// These complement the wire-level `EndToEndHappyPathTests`: those prove the
/// transport delivers events; these prove the host's *view model* correctly
/// gates trigger requests by `session.triggerPermission`.
///
/// We bypass `onAppear()` (which would start the camera and the Combine
/// pipeline) and call `handle(_:)` directly. For paths that spawn an internal
/// `Task` to run the countdown, we let it kick off, assert the synchronous
/// state transition, then `cancelCountdown()` so the spawned task short-
/// circuits before reaching the camera-capture call.
@MainActor
final class HostSessionViewModelPermissionTests: XCTestCase {

    // ── hostOnly ───────────────────────────────────────────────────────────
    //
    // The strictest setting — viewer requests must be silently dropped, no
    // pending list, no countdown.
    func test_hostOnly_captureRequested_isIgnored() {
        let vm = HostSessionViewModel(hostName: "Captain")
        vm.session.triggerPermission = .hostOnly

        vm.handle(.captureRequested(by: "v1"))

        XCTAssertTrue(vm.pendingCaptureRequests.isEmpty,
                      "hostOnly must not enqueue requests")
        XCTAssertCountdownIdle(vm)
    }

    // hostOnly also blocks captureNowRequested. Synchronous — no Task spawned
    // for this permission level, so we can assert immediately.
    func test_hostOnly_captureNowRequested_isIgnored() {
        let vm = HostSessionViewModel(hostName: "Captain")
        vm.session.triggerPermission = .hostOnly

        vm.handle(.captureNowRequested(by: "v1"))

        XCTAssertCountdownIdle(vm)
    }

    // ── viewersCanRequest ──────────────────────────────────────────────────
    //
    // Mid-trust setting. A viewer's request must land in `pendingCaptureRequests`
    // and *not* start a countdown — the captain still has to approve.
    func test_viewersCanRequest_captureRequested_addsToPending() {
        let vm = HostSessionViewModel(hostName: "Captain")
        vm.session.triggerPermission = .viewersCanRequest

        vm.handle(.captureRequested(by: "v2"))

        XCTAssertEqual(vm.pendingCaptureRequests, ["v2"])
        XCTAssertCountdownIdle(vm)
    }

    // Idempotent: a second request from the same viewer must not duplicate.
    // The host UI groups requests per participant, so duplicates would cause
    // visual glitches and inflated approve buttons.
    func test_viewersCanRequest_duplicateRequest_isDeduplicated() {
        let vm = HostSessionViewModel(hostName: "Captain")
        vm.session.triggerPermission = .viewersCanRequest

        vm.handle(.captureRequested(by: "v2"))
        vm.handle(.captureRequested(by: "v2"))

        XCTAssertEqual(vm.pendingCaptureRequests, ["v2"],
                       "Same participant requesting twice must not double-enqueue")
    }

    // captureNowRequested under viewersCanRequest is *not* a request for
    // approval — it's an "immediate fire" event the webapp never sends in this
    // mode. The host must reject it (no countdown, no pending entry).
    func test_viewersCanRequest_captureNowRequested_isIgnored() {
        let vm = HostSessionViewModel(hostName: "Captain")
        vm.session.triggerPermission = .viewersCanRequest

        vm.handle(.captureNowRequested(by: "v2"))

        XCTAssertTrue(vm.pendingCaptureRequests.isEmpty)
        XCTAssertCountdownIdle(vm)
    }

    // ── everyoneCanStartTimer ──────────────────────────────────────────────
    //
    // Open-trigger setting. Viewer's request goes straight to a countdown,
    // no captain approval required. We pick a 30s timer so the spawned
    // countdown task can't reach the camera-capture call before we cancel.
    func test_everyoneCanStartTimer_captureRequested_startsCountdown() async throws {
        let vm = HostSessionViewModel(hostName: "Captain")
        vm.session.triggerPermission = .everyoneCanStartTimer
        vm.session.timerDuration = 30

        vm.handle(.captureRequested(by: "v3"))
        try await Task.sleep(nanoseconds: 30_000_000)  // let the spawned Task run countdown.start()

        XCTAssertTrue(vm.countdown.state.isActive,
                      "Countdown must transition to running")
        XCTAssertTrue(vm.pendingCaptureRequests.isEmpty,
                      "No pending entry — direct trigger, not approval flow")

        // Cancel before the spawned task's Task.sleep elapses — the
        // `if case .idle = countdown.state { return }` check in startCountdown
        // then short-circuits, so capture() is never called and the camera
        // is never touched.
        await vm.cancelCountdown()
    }

    // ── viewersCanRequest → approve flow ───────────────────────────────────
    //
    // Approval clears the pending entry and starts the countdown. We spawn
    // approve() in a detached Task because it itself awaits a 30s sleep.
    func test_viewersCanRequest_approve_clearsPendingAndStartsCountdown() async throws {
        let vm = HostSessionViewModel(hostName: "Captain")
        vm.session.triggerPermission = .viewersCanRequest
        vm.session.timerDuration = 30

        vm.handle(.captureRequested(by: "v4"))
        XCTAssertEqual(vm.pendingCaptureRequests, ["v4"])

        // approve() awaits startCountdown() which awaits a 30s sleep — spawn
        // it so we can assert + cancel without blocking the test.
        let approveTask = Task { await vm.approve(participantID: "v4") }
        try await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertTrue(vm.pendingCaptureRequests.isEmpty,
                      "Approval must drain the pending list")
        XCTAssertTrue(vm.countdown.state.isActive,
                      "Approval must start the countdown")

        await vm.cancelCountdown()
        approveTask.cancel()
        _ = await approveTask.value
    }

    // Deny clears the pending entry and does NOT start a countdown.
    func test_viewersCanRequest_deny_clearsPendingNoCountdown() async {
        let vm = HostSessionViewModel(hostName: "Captain")
        vm.session.triggerPermission = .viewersCanRequest

        vm.handle(.captureRequested(by: "v5"))
        XCTAssertEqual(vm.pendingCaptureRequests, ["v5"])

        await vm.deny(participantID: "v5")

        XCTAssertTrue(vm.pendingCaptureRequests.isEmpty)
        XCTAssertCountdownIdle(vm)
    }

    // MARK: - Helpers

    /// Pattern-matching `case` inside `XCTAssert` is awkward, so we bottle it.
    private func XCTAssertCountdownIdle(_ vm: HostSessionViewModel,
                                        file: StaticString = #file,
                                        line: UInt = #line) {
        if case .idle = vm.countdown.state { return }
        XCTFail("Expected countdown to be .idle, got \(vm.countdown.state)",
                file: file, line: line)
    }
}
