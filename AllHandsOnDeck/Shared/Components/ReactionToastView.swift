import SwiftUI

struct ReactionToastView: View {
    let reaction: Reaction
    let from: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: reaction.symbol)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.black)
                .frame(width: 32, height: 32)
                .background(Theme.goldShine, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(reaction.label)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.bone)
                Text(from)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.mist)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(
                reaction.isFramingHint ? Theme.gold.opacity(0.6) : Color.white.opacity(0.1),
                lineWidth: 1
            )
        )
    }
}
