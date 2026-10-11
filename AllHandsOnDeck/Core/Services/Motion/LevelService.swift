import Foundation
import CoreMotion

/// Reads device tilt from CoreMotion and exposes a roll angle (in degrees,
/// 0 = portrait-perfect, ±90 = on its side) plus an `isLevel` convenience.
///
/// Reference-counted: views call `start()` on appear and `stop()` on disappear.
/// The CMMotionManager runs only while at least one consumer is active.
@MainActor
final class LevelService: ObservableObject {
    static let shared = LevelService()

    @Published private(set) var rollDegrees: Double = 0

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var refCount = 0

    var isLevel: Bool { abs(rollDegrees) < 2.0 }

    private init() {
        queue.qualityOfService = .userInitiated
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
    }

    func start() {
        refCount += 1
        guard refCount == 1, motionManager.isDeviceMotionAvailable else { return }
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let motion else { return }
            // Roll relative to portrait derived from gravity; atan2(x, -y) gives
            // 0 when the phone is upright, positive when the top tilts right.
            let g = motion.gravity
            let roll = atan2(g.x, -g.y) * 180.0 / .pi
            Task { @MainActor in self?.rollDegrees = roll }
        }
    }

    func stop() {
        refCount = max(0, refCount - 1)
        if refCount == 0 { motionManager.stopDeviceMotionUpdates() }
    }
}
