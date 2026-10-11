import SwiftUI

struct CountdownOverlayView: View {
    let state: CountdownState
    let remainingSeconds: Int

    var body: some View {
        ZStack {
            switch state {
            case .running:
                running
            case .capturing:
                capturing
            default:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: remainingSeconds)
        .animation(.easeInOut(duration: 0.25), value: stateID)
        .allowsHitTesting(false)
    }

    private var running: some View {
        ZStack {
            Color.black.opacity(0.18).ignoresSafeArea()
            Text("\(remainingSeconds)")
                .font(.system(size: 220, weight: .black, design: .rounded))
                .foregroundStyle(Theme.goldShine)
                .shadow(color: Theme.gold.opacity(0.5), radius: 30, y: 4)
                .contentTransition(.numericText(countsDown: true))
                .id(remainingSeconds) // force transition each tick
        }
        .transition(.opacity)
    }

    private var capturing: some View {
        ZStack {
            Color.white.opacity(0.95).ignoresSafeArea()
        }
        .transition(.opacity)
    }

    /// Stable identifier per state case, used to drive transitions.
    private var stateID: Int {
        switch state {
        case .idle: return 0
        case .running: return 1
        case .capturing: return 2
        case .completed: return 3
        }
    }
}
