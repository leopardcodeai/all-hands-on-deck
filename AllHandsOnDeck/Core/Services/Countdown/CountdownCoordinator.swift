import Foundation
import Combine

/// Drives the countdown UI off a target Date, not a per-tick counter — so all
/// clients converge on the same fire moment regardless of network jitter.
///
/// Host calls `start(duration:)` to publish a `photoAt` to peers; both host and
/// viewers run an identical local timer that just measures `photoAt - now`.
@MainActor
final class CountdownCoordinator: ObservableObject {
    @Published private(set) var state: CountdownState = .idle
    /// Seconds remaining (rounded up). Updates ~10x/sec while running.
    @Published private(set) var remainingSeconds: Int = 0

    private var ticker: AnyCancellable?

    /// Local-only start. Use `armRunning(photoAt:duration:)` to sync from a
    /// peer-published target date.
    func start(duration: Int) -> Date {
        let photoAt = Date().addingTimeInterval(TimeInterval(duration))
        armRunning(photoAt: photoAt, duration: duration)
        return photoAt
    }

    /// Sync to a target date that someone (host or peer) already announced.
    func armRunning(photoAt: Date, duration: Int) {
        state = .running(photoAt: photoAt, duration: duration)
        remainingSeconds = max(0, Int(ceil(photoAt.timeIntervalSinceNow)))
        startTicker(photoAt: photoAt)
    }

    func cancel() {
        ticker?.cancel()
        ticker = nil
        state = .idle
        remainingSeconds = 0
    }

    func markCapturing() {
        ticker?.cancel()
        ticker = nil
        state = .capturing
        remainingSeconds = 0
    }

    func markCompleted() {
        ticker?.cancel()
        ticker = nil
        state = .completed
        remainingSeconds = 0
    }

    private func startTicker(photoAt: Date) {
        ticker?.cancel()
        ticker = Timer
            .publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let remaining = photoAt.timeIntervalSinceNow
                if remaining <= 0 {
                    self.remainingSeconds = 0
                    self.markCapturing()
                } else {
                    let newValue = max(0, Int(ceil(remaining)))
                    if newValue != self.remainingSeconds {
                        self.remainingSeconds = newValue
                        Haptics.tick()
                    }
                }
            }
    }
}
