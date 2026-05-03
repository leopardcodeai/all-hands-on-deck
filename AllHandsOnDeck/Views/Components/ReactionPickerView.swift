import SwiftUI

struct ReactionPickerView: View {
    var onReact: (Reaction) -> Void
    @State private var lastSent: Reaction?

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 4)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Reaction.allCases) { r in
                Button {
                    Haptics.tap()
                    lastSent = r
                    onReact(r)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if lastSent == r { lastSent = nil }
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: r.symbol)
                            .font(.system(size: 13, weight: .heavy))
                        Text(r.label)
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.4)
                    }
                    .padding(.horizontal, 2)
                    .foregroundStyle(lastSent == r ? .black : Theme.bone)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        lastSent == r
                            ? AnyShapeStyle(Theme.goldShine)
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
