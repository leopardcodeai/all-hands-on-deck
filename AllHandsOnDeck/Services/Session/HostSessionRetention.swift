import Foundation

/// Holds a host VM in limbo for up to 10 seconds after the host view disappears,
/// so the captain can briefly drop back to Home and resume without losing the
/// session, transport, or camera state.
///
/// Lifecycle:
/// - `park(_:)` retains the VM and starts a teardown timer.
/// - `consume()` atomically claims the parked VM and cancels the timer.
/// - If the timer fires, `shutdown()` is called and the VM is released.
@MainActor
final class HostSessionRetention: ObservableObject {
    static let shared = HostSessionRetention()

    /// Seconds remaining in the park window. `nil` when no VM is parked.
    /// Drives the resume countdown shown on Home.
    @Published private(set) var remainingSeconds: Int?

    private var parkedVM: HostSessionViewModel?
    private var teardownTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var activeToken: UUID?

    private let parkDuration: Int

    private init() { parkDuration = 10 }

    /// Designated init exposed for unit tests (not the singleton path).
    init(parkDuration: Int) { self.parkDuration = parkDuration }

    /// Park `vm` and start the 10s teardown timer. If a different VM is already
    /// parked, the previous one is shut down immediately (newest wins).
    func park(_ vm: HostSessionViewModel) {
        if let existing = parkedVM, existing !== vm {
            existing.shutdown()
        }
        cancelTimers()

        parkedVM = vm
        let token = UUID()
        activeToken = token
        remainingSeconds = parkDuration
        let total = parkDuration

        tickTask = Task { @MainActor [weak self] in
            for s in stride(from: total - 1, through: 0, by: -1) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled, self.activeToken == token else { return }
                self.remainingSeconds = s
            }
        }

        teardownTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(total) * 1_000_000_000)
            guard let self, !Task.isCancelled, self.activeToken == token else { return }
            self.parkedVM?.shutdown()
            Task { @MainActor [weak self] in
                self?.remainingSeconds = nil
            }
            self.parkedVM = nil
            self.activeToken = nil
        }
    }

    /// Atomically claim the parked VM and cancel the teardown timer.
    /// Returns `nil` if no VM is parked or it just expired.
    func consume() -> HostSessionViewModel? {
        let vm = parkedVM
        parkedVM = nil
        activeToken = nil
        Task { @MainActor [weak self] in
            self?.remainingSeconds = nil
        }
        return vm
    }

    private func cancelTimers() {
        teardownTask?.cancel()
        teardownTask = nil
        tickTask?.cancel()
        tickTask = nil
    }
}
