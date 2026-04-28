import SwiftUI

struct ReactionPickerView: View {
    var onReact: (Reaction) -> Void
    @State private var lastSent: Reaction?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Reaction.allCases) { r in
                Button {
                    Haptics.tap()
                    lastSent = r
                    onReact(r)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if lastSent == r { lastSent = nil }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: r.symbol)
                            .font(.system(size: 17, weight: .heavy))
                        Text(r.label)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(lastSent == r ? .black : Theme.bone)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        lastSent == r
                            ? AnyShapeStyle(Theme.goldShine)
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
