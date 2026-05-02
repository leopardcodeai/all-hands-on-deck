import SwiftUI

struct StatusPill: View {
    let label: String
    var systemImage: String?
    var tint: Color = Theme.signal

    var body: some View {
        HStack(spacing: 6) {
            if let s = systemImage {
                Image(systemName: s).font(.system(size: 11, weight: .bold))
            }
            Text(label.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.0)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12))
        .overlay(
            Capsule().stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}
