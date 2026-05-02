import XCTest
@testable import AllHandsOnDeck

@MainActor
final class CountdownCoordinatorTests: XCTestCase {
    func test_initialState_isIdle() {
        let c = CountdownCoordinator()
        XCTAssertEqual(c.state, .idle)
        XCTAssertEqual(c.remainingSeconds, 0)
    }

    func test_start_setsRunningStateWithFutureTarget() {
        let c = CountdownCoordinator()
        let before = Date()
        let target = c.start(duration: 10)
        let after = Date()

        if case .running(let date, let dur) = c.state {
            XCTAssertEqual(dur, 10)
            // Target lands ~10s into the future.
            XCTAssertEqual(date.timeIntervalSince(before), 10, accuracy: 0.5)
            XCTAssertEqual(target, date)
            XCTAssertGreaterThanOrEqual(target.timeIntervalSince(after), 9)
        } else {
            XCTFail("Expected .running, got \(c.state)")
        }
    }

    func test_armRunning_acceptsExternalTargetDate() {
        let c = CountdownCoordinator()
        let target = Date().addingTimeInterval(7)
        c.armRunning(photoAt: target, duration: 7)

        if case .running(let date, let dur) = c.state {
            XCTAssertEqual(dur, 7)
            XCTAssertEqual(date, target)
        } else {
            XCTFail("Expected .running")
        }
        // remainingSeconds should be ceil-rounded → 7
        XCTAssertEqual(c.remainingSeconds, 7)
    }

    func test_cancel_returnsToIdle() {
        let c = CountdownCoordinator()
        _ = c.start(duration: 10)
        c.cancel()
        XCTAssertEqual(c.state, .idle)
        XCTAssertEqual(c.remainingSeconds, 0)
    }

    func test_markCapturing_setsCapturingAndStopsTicker() async throws {
        let c = CountdownCoordinator()
        _ = c.start(duration: 5)
        c.markCapturing()
        XCTAssertEqual(c.state, .capturing)
        XCTAssertEqual(c.remainingSeconds, 0)

        // After half a second the state should still be .capturing — ticker
        // should be cancelled.
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(c.state, .capturing)
    }

    func test_markCompleted_setsCompleted() {
        let c = CountdownCoordinator()
        _ = c.start(duration: 5)
        c.markCompleted()
        XCTAssertEqual(c.state, .completed)
    }

    func test_isActive_truthTable() {
        XCTAssertFalse(CountdownState.idle.isActive)
        XCTAssertTrue(CountdownState.running(photoAt: Date(), duration: 5).isActive)
        XCTAssertTrue(CountdownState.capturing.isActive)
        XCTAssertFalse(CountdownState.completed.isActive)
    }
}
