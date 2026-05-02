import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var style: Style = .primary
    var isLoading: Bool = false
    let action: () -> Void

    enum Style { case primary, secondary, ghost, destructive }

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(foreground)
                } else if let s = systemImage {
                    Image(systemName: s).font(.system(size: 17, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: shadowColor, radius: 16, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            Theme.goldShine
        case .secondary:
            Theme.deck
        case .ghost:
            Color.white.opacity(0.04)
        case .destructive:
            Theme.crimson.opacity(0.85)
        }
    }

    private var foreground: Color {
        switch style {
        case .primary: return .black
        case .destructive: return Theme.bone
        default: return Theme.bone
        }
    }

    private var strokeColor: Color {
        switch style {
        case .primary: return Color.white.opacity(0.25)
        case .secondary: return Color.white.opacity(0.06)
        case .ghost: return Color.white.opacity(0.10)
        case .destructive: return Color.white.opacity(0.15)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .primary: return Theme.gold.opacity(0.35)
        case .destructive: return Theme.crimson.opacity(0.35)
        default: return .black.opacity(0.3)
        }
    }
}
