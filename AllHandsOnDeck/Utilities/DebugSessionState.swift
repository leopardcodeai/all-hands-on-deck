import Foundation

/// Live debug counters — shared observable for the debug overlay.
/// All writes happen on @MainActor; reads from the overlay are safe.
@MainActor
final class DebugSessionState: ObservableObject {
    static let shared = DebugSessionState()

    // Camera / frames
    @Published var framesProduced: Int = 0
    @Published var framesBroadcast: Int = 0
    @Published var framesReceived: Int = 0
    @Published var framesPerSecond: Double = 0
    @Published var cameraIsRunning = false

    // Firebase
    @Published var firebaseFramesWritten: Int = 0
    @Published var firebaseFramesRead: Int = 0
    @Published var firebaseMsgsPolled: Int = 0
    @Published var firebaseWritesFailed: Int = 0
    @Published var firebaseReadsFailed: Int = 0
    @Published var firebaseLastWriteMs: TimeInterval = 0
    @Published var firebaseLastReadMs: TimeInterval = 0

    // Multipeer
    @Published var multipeerPeers: Int = 0
    @Published var multipeerFramesSent: Int = 0
    @Published var multipeerFramesReceived: Int = 0

    // Session
    @Published var transportStatus = "idle"
    @Published var participantCount = 0
    @Published var lastEvents: [String] = []
    @Published var sessionID = ""

    private var frameTickStart = Date()
    private var frameTickCount = 0

    func recordFrameProduced() {
        framesProduced += 1
        frameTickCount += 1
        let elapsed = Date().timeIntervalSince(frameTickStart)
        if elapsed >= 1.0 {
            framesPerSecond = Double(frameTickCount) / elapsed
            frameTickCount = 0
            frameTickStart = Date()
        }
    }

    func recordFrameBroadcast() { framesBroadcast &+= 1 }
    func recordFrameReceived() { framesReceived &+= 1 }
    func recordFirebaseWrite(success: Bool) {
        if success { firebaseFramesWritten &+= 1; firebaseLastWriteMs = 0 }
        else { firebaseWritesFailed &+= 1 }
    }
    func recordFirebaseRead(success: Bool) {
        if success { firebaseFramesRead &+= 1; firebaseLastReadMs = 0 }
        else { firebaseReadsFailed &+= 1 }
    }
    func recordFirebaseMsgsPoll() { firebaseMsgsPolled &+= 1 }
    func recordMultipeerFrame(sent: Bool) {
        if sent { multipeerFramesSent &+= 1 } else { multipeerFramesReceived &+= 1 }
    }
    func recordEvent(_ label: String) {
        lastEvents.append(label)
        if lastEvents.count > 5 { lastEvents.removeFirst() }
    }
    func reset() {
        framesProduced = 0; framesBroadcast = 0; framesReceived = 0
        framesPerSecond = 0; firebaseFramesWritten = 0; firebaseFramesRead = 0
        firebaseMsgsPolled = 0; firebaseWritesFailed = 0; firebaseReadsFailed = 0
        multipeerPeers = 0; multipeerFramesSent = 0; multipeerFramesReceived = 0
        lastEvents = []
    }
}

/// Non-isolated accessor for the frame producer (called from video queue).
func debugRecordFrameProduced() {
    Task { @MainActor in DebugSessionState.shared.recordFrameProduced() }
}
