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

    // Supabase
    @Published var supabaseFramesWritten: Int = 0
    @Published var supabaseFramesRead: Int = 0
    @Published var supabaseMsgsPolled: Int = 0
    @Published var supabaseWritesFailed: Int = 0
    @Published var supabaseReadsFailed: Int = 0
    @Published var supabaseLastWriteMs: TimeInterval = 0
    @Published var supabaseLastReadMs: TimeInterval = 0

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
    func recordSupabaseWrite(success: Bool) {
        if success { supabaseFramesWritten &+= 1; supabaseLastWriteMs = 0 }
        else { supabaseWritesFailed &+= 1 }
    }
    func recordSupabaseRead(success: Bool) {
        if success { supabaseFramesRead &+= 1; supabaseLastReadMs = 0 }
        else { supabaseReadsFailed &+= 1 }
    }
    func recordSupabaseMsgsPoll() { supabaseMsgsPolled &+= 1 }
    func recordMultipeerFrame(sent: Bool) {
        if sent { multipeerFramesSent &+= 1 } else { multipeerFramesReceived &+= 1 }
    }
    func recordEvent(_ label: String) {
        lastEvents.append(label)
        if lastEvents.count > 5 { lastEvents.removeFirst() }
    }
    func reset() {
        framesProduced = 0; framesBroadcast = 0; framesReceived = 0
        framesPerSecond = 0; supabaseFramesWritten = 0; supabaseFramesRead = 0
        supabaseMsgsPolled = 0; supabaseWritesFailed = 0; supabaseReadsFailed = 0
        multipeerPeers = 0; multipeerFramesSent = 0; multipeerFramesReceived = 0
        lastEvents = []
    }
}

/// Non-isolated accessor for the frame producer (called from video queue).
func debugRecordFrameProduced() {
    Task { @MainActor in DebugSessionState.shared.recordFrameProduced() }
}
