import SwiftUI

struct DebugOverlayView: View {
    @ObservedObject private var state = DebugSessionState.shared
    @State private var expanded = false
    let version: String

    init(version: String = "2.4.2") {
        self.version = version
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                // Always-visible summary bar
                Button { withAnimation(.spring(response: 0.3)) { expanded.toggle() } } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(state.cameraIsRunning ? Theme.signal : Theme.crimson)
                            .frame(width: 6, height: 6)
                        Text(String(format: "%.0f fps", state.framesPerSecond))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Text("SB:\(state.supabaseFramesWritten)/\(state.supabaseFramesRead) ")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Text("MP:\(state.multipeerPeers)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Spacer()
                        Text("v\(version)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.crimson.opacity(0.8))
                        Image(systemName: expanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Theme.bone.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                if expanded {
                    detailPanel
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 3) {
            row("Transport", state.transportStatus)
            row("Session", state.sessionID.isEmpty ? "—" : state.sessionID)
            row("Participants", "\(state.participantCount)")
            row("Frames produced", "\(state.framesProduced) (\(state.framesBroadcast) broadcast)")
            row("Frames received", "\(state.framesReceived)")
            Divider().opacity(0.3)
            row(DesignLabels.debugSupabaseWrites, "\(state.supabaseFramesWritten) ok / \(state.supabaseWritesFailed) fail")
            row(DesignLabels.debugSupabaseReads, "\(state.supabaseFramesRead) ok / \(state.supabaseReadsFailed) fail")
            row(DesignLabels.debugSupabasePolls, "\(state.supabaseMsgsPolled)")
            row("Multipeer peers", "\(state.multipeerPeers)")
            row("MP frames sent/recv", "\(state.multipeerFramesSent)/\(state.multipeerFramesReceived)")
            Divider().opacity(0.3)
            row("Last events", state.lastEvents.isEmpty ? "—" : "")
            ForEach(state.lastEvents.reversed(), id: \.self) { e in
                Text(e)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.mist)
                    .padding(.leading, 4)
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(Theme.bone.opacity(0.7))
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxHeight: 260)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.mist)
            Spacer()
            Text(value)
                .foregroundStyle(value.contains("fail") ? Theme.crimson : Theme.bone.opacity(0.8))
        }
        .padding(.horizontal, 2)
    }
}
