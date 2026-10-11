import SwiftUI

/// Rule-of-thirds grid + safe area outline. Pure SwiftUI, no input handling.
struct SafeGridOverlayView: View {
    var color = Color.white.opacity(0.35)
    var safeInset: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // 3x3 grid lines
                Path { p in
                    for i in 1..<3 {
                        let x = w * CGFloat(i) / 3
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h))
                    }
                    for i in 1..<3 {
                        let y = h * CGFloat(i) / 3
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                }
                .stroke(color, lineWidth: 0.5)

                // Safe-area frame
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .inset(by: safeInset)
                    .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            }
        }
        .allowsHitTesting(false)
    }
}
