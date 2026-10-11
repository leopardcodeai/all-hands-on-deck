import SwiftUI

// MARK: - Procedural Leopard Spots (used by legacy LeopardTextureView)

struct SeededGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z &>> 27)) &* 0x94d049bb133111eb
        z = z ^ (z &>> 31)
        return z
    }
    mutating func double() -> Double { Double(next() % 10_000) / 10_000.0 }
}

struct LeopardSpot {
    let center: CGPoint; let radiusX: CGFloat; let radiusY: CGFloat; let rotation: Double
}

struct LeopardSpotShape: Shape {
    var density: Int; var seed: UInt64
    func path(in rect: CGRect) -> Path {
        var rng = SeededGenerator(seed: seed)
        var spots: [LeopardSpot] = []
        for _ in 0..<density {
            let x = CGFloat(rng.double()) * rect.width
            let y = CGFloat(rng.double()) * rect.height
            let rx = 4 + CGFloat(rng.double()) * 18
            let ry = 3 + CGFloat(rng.double()) * 14
            spots.append(LeopardSpot(center: CGPoint(x: x, y: y),
                                     radiusX: rx, radiusY: ry,
                                     rotation: rng.double() * .pi))
        }
        var path = Path()
        for s in spots {
            path.addEllipse(in: CGRect(x: s.center.x - s.radiusX, y: s.center.y - s.radiusY,
                                       width: s.radiusX * 2, height: s.radiusY * 2))
        }
        return path
    }
}

// MARK: - Full Leopard Wallpaper Compositing

/// Full Leopard wallpaper compositing — 4 überlagerte Schichten.
///
/// Schichten:
///   1. Leopard-PNG (abgedunkelt + entsättigt)
///   2. Linearer Verlauf (bg → ink → ink)
///   3. Goldener Radialverlauf (oben-links)
///   4. Blauer Radialverlauf (unten-rechts, screen blend)
struct LeopardWallpaperView: View {
    var body: some View {
        Color.clear
            .overlay {
                // Schicht 1: Leopard-PNG mit Nachbearbeitung
                Image("LeopardPattern")
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .saturation(0.76)
                    .contrast(0.86)
                    .brightness(-0.12)
                    .overlay(Theme.ink.opacity(0.52))

                // Schicht 2: Linearer Verlauf von oben nach unten
                LinearGradient(
                    colors: [
                        Theme.bg.opacity(0.46),
                        Theme.ink.opacity(0.18),
                        Theme.ink.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Schicht 3: Goldener Radialverlauf von oben-links
                RadialGradient(
                    colors: [Theme.gold.opacity(0.18), .clear],
                    center: .topLeading,
                    startRadius: 16,
                    endRadius: 320
                )

                // Schicht 4: Blauer Radialverlauf von unten-rechts (screen blend)
                RadialGradient(
                    colors: [Theme.focusBlue.opacity(0.10), .clear],
                    center: .bottomTrailing,
                    startRadius: 12,
                    endRadius: 280
                )
                .blendMode(.screen)
            }
            .background(Theme.ink)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

/// Legacy leopard spot texture overlay (procedural, ohne PNG).
/// Use `LeopardWallpaperView` for the full composited background.
struct LeopardTextureView: View {
    var opacity: Double = 0.04
    var density: Int = 30
    var seed: UInt64 = 7

    var body: some View {
        LeopardSpotShape(density: density, seed: seed)
            .fill(Theme.amber)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

// MARK: - Previews

#Preview("Wallpaper") {
    LeopardWallpaperView()
}

#Preview("Legacy Texture") {
    ZStack {
        Theme.abyss.ignoresSafeArea()
        LeopardTextureView(density: 50, seed: 42)
    }
}
