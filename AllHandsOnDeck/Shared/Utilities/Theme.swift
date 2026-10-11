import SwiftUI

/// LeopardCode.AI's pirate-meets-engineering palette.
/// Deep ocean black, warm leopard amber, pirate gold, signal teal.
enum Theme {
    // MARK: - Colors

    /// Almost-black ocean background.
    static let abyss = Color(red: 0.04, green: 0.05, blue: 0.07)
    /// Slightly lifted card surface.
    static let deck = Color(red: 0.09, green: 0.10, blue: 0.13)
    /// Pirate gold — primary accent.
    static let gold = Color(red: 0.95, green: 0.74, blue: 0.18)
    /// Leopard amber — secondary warm tone.
    static let amber = Color(red: 0.86, green: 0.49, blue: 0.13)
    /// Signal teal — for live / connected states.
    static let signal = Color(red: 0.27, green: 0.83, blue: 0.78)
    /// Soft warning crimson.
    static let crimson = Color(red: 0.92, green: 0.34, blue: 0.36)
    /// Bone white for primary text.
    static let bone = Color(red: 0.96, green: 0.95, blue: 0.91)
    /// Muted text.
    static let mist = Color(red: 0.66, green: 0.68, blue: 0.72)
    /// Deep ink black — wallpaper background.
    static let ink = Color(red: 0.039, green: 0.039, blue: 0.043)   // #0A0A0B
    /// Slightly lifted bg.
    static let bg = Color(red: 0.059, green: 0.059, blue: 0.071)    // #0F0F12
    /// Focus blue — accent for screen blend.
    static let focusBlue = Color(red: 0.216, green: 0.541, blue: 0.867) // #378ADD

    // MARK: - Gradients

    static let goldShine = LinearGradient(
        colors: [gold, amber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let oceanFog = LinearGradient(
        colors: [abyss, Color.black],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Type

    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func mono(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

// MARK: - Spacing

/// Design system spacing tokens. No magic numbers in views.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    static let cornerSm: CGFloat = 8
    static let cornerMd: CGFloat = 14
    static let cornerLg: CGFloat = 22

    static let buttonHeight: CGFloat = 50
    static let iconSizeSm: CGFloat = 36
    static let iconSizeMd: CGFloat = 40
    static let iconSizeLg: CGFloat = 48
}

/// Liquid glass-style surface. Falls back to .ultraThinMaterial on older OSes.
struct LiquidGlass: ViewModifier {
    var cornerRadius: CGFloat = 22
    var stroke = Color.white.opacity(0.08)

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(stroke, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 22) -> some View {
        modifier(LiquidGlass(cornerRadius: cornerRadius))
    }
}
