import SwiftUI

struct InFrameHintView: View {
    let status: InFrameStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.symbol)
                .font(.system(size: 12, weight: .heavy))
            Text(status.headline)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
            if status.faceCount > 0 {
                Text("· \(status.faceCount)")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(status.isHappy ? AnyShapeStyle(Theme.signal) : AnyShapeStyle(Theme.gold))
        .clipShape(Capsule())
        .shadow(color: (status.isHappy ? Theme.signal : Theme.gold).opacity(0.3), radius: 12, y: 4)
    }
}
