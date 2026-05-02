import XCTest
@testable import AllHandsOnDeck

@MainActor
final class HostSessionRetentionTests: XCTestCase {
    func test_initialState_noParkedVM() {
        let r = HostSessionRetention.shared
        // Shared instance starts clean (or has expired); not deeply testable
        // without resetting shared state — so just verify the type compiles.
        XCTAssertNil(r.remainingSeconds, "No VM parked at start")
    }

    func test_park_setsRemainingSeconds() {
        let r = HostSessionRetention.shared
        let vm = makeVM()
        r.park(vm)
        XCTAssertNotNil(r.remainingSeconds)
        XCTAssertEqual(r.remainingSeconds, 10)
        // Clean up
        _ = r.consume()
    }

    func test_consume_returnsParkedVM() {
        let r = HostSessionRetention.shared
        let vm = makeVM()
        r.park(vm)
        let claimed = r.consume()
        XCTAssertTrue(claimed === vm, "consume() should return the parked VM")
    }

    func test_consume_clearsRemainingSeconds() {
        let r = HostSessionRetention.shared
        let vm = makeVM()
        r.park(vm)
        _ = r.consume()
        XCTAssertNil(r.remainingSeconds)
    }

    func test_consume_whenEmpty_returnsNil() {
        let r = HostSessionRetention.shared
        // Ensure nothing is parked
        _ = r.consume()
        let result = r.consume()
        XCTAssertNil(result)
    }

    func test_parkSecondVM_replacesFirst() {
        let r = HostSessionRetention.shared
        let vm1 = makeVM()
        let vm2 = makeVM()
        r.park(vm1)
        r.park(vm2)
        let claimed = r.consume()
        XCTAssertTrue(claimed === vm2, "Second park should win")
    }

    func test_expire_clearsVMAndRemainingSeconds() async throws {
        let r = HostSessionRetention(parkDuration: 1)
        let vm = makeVM()
        r.park(vm)
        XCTAssertNotNil(r.remainingSeconds)
        // Wait long enough for the 1s teardown to fire.
        try await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertNil(r.remainingSeconds, "Timer should have expired")
        XCTAssertNil(r.consume(), "Expired VM should not be claimable")
    }

    // MARK: - Helpers

    private func makeVM() -> HostSessionViewModel {
        HostSessionViewModel(hostName: "TestCaptain")
    }
}
