import SwiftUI

/// Deterministic seeded PRNG for consistent leopard spot patterns.
struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z &>> 27)) &* 0x94d049bb133111eb
        z = z ^ (z &>> 31)
        return z
    }

    mutating func double() -> Double {
        Double(next() % 10_000) / 10_000.0
    }
}

/// A single leopard spot — an ellipse with position and size.
struct LeopardSpot {
    let center: CGPoint
    let radiusX: CGFloat
    let radiusY: CGFloat
    let rotation: Double
}

/// Shape that renders deterministic leopard spots from a seed.
struct LeopardSpotShape: Shape {
    var density: Int
    var seed: UInt64

    func path(in rect: CGRect) -> Path {
        var rng = SeededGenerator(seed: seed)
        var spots: [LeopardSpot] = []

        for _ in 0..<density {
            let x = CGFloat(rng.double()) * rect.width
            let y = CGFloat(rng.double()) * rect.height
            let rx = 4 + CGFloat(rng.double()) * 18
            let ry = 3 + CGFloat(rng.double()) * 14
            let rot = rng.double() * .pi

            spots.append(LeopardSpot(
                center: CGPoint(x: x, y: y),
                radiusX: rx,
                radiusY: ry,
                rotation: rot
            ))
        }

        var path = Path()
        for spot in spots {
            let ellipseRect = CGRect(
                x: spot.center.x - spot.radiusX,
                y: spot.center.y - spot.radiusY,
                width: spot.radiusX * 2,
                height: spot.radiusY * 2
            )
            path.addEllipse(in: ellipseRect)
        }
        return path
    }
}

/// Subtle leopard-spot texture overlay for background layers.
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

#Preview {
    ZStack {
        Theme.abyss.ignoresSafeArea()
        LeopardTextureView(density: 50, seed: 42)
    }
}
