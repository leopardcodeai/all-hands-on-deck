import SwiftUI
import WatchKit

/// Three states: no host, idle host, countdown running. Drive everything off
/// `bridge.snapshot` so the watch is a pure mirror of phone state.
struct WatchRootView: View {
    @EnvironmentObject var bridge: WatchSideBridge

    var body: some View {
        ZStack {
            background

            if bridge.snapshot.sessionID == nil {
                idleView
            } else if bridge.snapshot.countdown == .running {
                countdownView
            } else {
                liveView
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.05, blue: 0.07), .black],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(Color(red: 0.95, green: 0.74, blue: 0.18))
            Text("Keine Session")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
            Text("Starte eine Gruppenfoto-Session auf deinem iPhone, dann erscheint hier die Fernbedienung.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                bridge.send(.requestSnapshot)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 12)
    }

    private var liveView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 0.27, green: 0.83, blue: 0.78))
                    .frame(width: 8, height: 8)
                Text("LIVE")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.0)
                Spacer()
                Text("\(bridge.snapshot.participantCount)")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
            }
            Text(bridge.snapshot.hostName)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            if let label = bridge.snapshot.lastReactionLabel {
                Text("⌁ \(label)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.95, green: 0.74, blue: 0.18))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                bridge.send(.startTimer)
                WKInterfaceDevice.current().play(.click)
            } label: {
                Label(String(format: String(localized: "watch.timerButton"), bridge.snapshot.timerDuration), systemImage: "timer")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .tint(Color(red: 0.95, green: 0.74, blue: 0.18))

            Button {
                bridge.send(.captureNow)
                WKInterfaceDevice.current().play(.success)
            } label: {
                Label("Jetzt", systemImage: "camera.fill")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 8)
    }

    private var countdownView: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
            let target = bridge.snapshot.photoAtEpochMs.map { Date(timeIntervalSince1970: $0 / 1000) }
            let remaining = max(0, Int(ceil(target?.timeIntervalSince(ctx.date) ?? 0)))
            VStack(spacing: 4) {
                Text("\(remaining)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 0.95, green: 0.74, blue: 0.18),
                                 Color(red: 0.86, green: 0.49, blue: 0.13)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                Button(role: .destructive) {
                    bridge.send(.cancelTimer)
                    WKInterfaceDevice.current().play(.failure)
                } label: {
                    Label("Abbrechen", systemImage: "xmark")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                }
            }
        }
    }
}
