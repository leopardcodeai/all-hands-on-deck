import SwiftUI

/// Burst-result chooser. Shows all candidate shots with scoring badges
/// (faces / eyes-open / sharpness) and lets the captain pick one.
struct BurstPickerView: View {
    let candidates: [CapturedPhoto]
    let scores: [PhotoScore]
    let isRanking: Bool
    var onPick: (CapturedPhoto) -> Void
    var onDiscard: () -> Void

    /// Order: scored-and-best first, fall back to capture order.
    private var orderedCandidates: [(CapturedPhoto, PhotoScore?)] {
        let scoreByIndex = Dictionary(uniqueKeysWithValues: scores.map { ($0.imageIndex, $0) })
        let ranked = scores.compactMap { s -> (CapturedPhoto, PhotoScore?)? in
            guard candidates.indices.contains(s.imageIndex) else { return nil }
            return (candidates[s.imageIndex], s)
        }
        let unrankedIndices = candidates.indices.filter { scoreByIndex[$0] == nil }
        let unranked = unrankedIndices.map { (candidates[$0], nil as PhotoScore?) }
        return ranked + unranked
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                header
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(orderedCandidates.enumerated()), id: \.offset) { rank, pair in
                            row(rank: rank, photo: pair.0, score: pair.1)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                footer
            }
            .padding(.vertical, 18)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Best Shot Burst")
                    .font(Theme.display(22))
                    .foregroundStyle(Theme.bone)
                Spacer()
                if isRanking {
                    ProgressView().tint(Theme.gold)
                }
            }
            Text("KI-Ranking nach Gesichtern, offenen Augen und Schärfe.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.mist)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private func row(rank: Int, photo: CapturedPhoto, score: PhotoScore?) -> some View {
        Button {
            Haptics.tap()
            onPick(photo)
        } label: {
            HStack(spacing: 14) {
                if let img = photo.uiImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 110, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if rank == 0 && score != nil {
                            Text("⭐︎ Beste")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Theme.goldShine)
                                .clipShape(Capsule())
                        }
                        Text(String(format: String(localized: "burst.shotNumber"), rank + 1))
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.bone)
                    }
                    if let s = score {
                        HStack(spacing: 8) {
                            metric("👥", "\(s.faceCount)")
                            metric("👁", String(format: "%.0f%%", s.eyesOpen * 100))
                            metric("✦", String(format: "%.0f%%", s.sharpness * 100))
                        }
                    } else {
                        Text("Bewerte…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.mist)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.mist)
            }
            .padding(10)
            .liquidGlass(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    private func metric(_ emoji: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(emoji).font(.system(size: 11))
            Text(value)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.bone)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    private var footer: some View {
        PrimaryButton(title: "Verwerfen", systemImage: "xmark", style: .ghost) { onDiscard() }
            .padding(.horizontal, 18)
    }
}
