import SwiftUI

struct QRCodePanelView: View {
    let payload: String
    let sessionID: String
    @State private var didCopy = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                QRCodeService.image(string: payload, size: 600)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(8)
                    .background(Theme.bone)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(width: 168, height: 168)
                Text("🏴‍☠️")
                    .font(.system(size: 28))
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            .frame(width: 168, height: 168)

            VStack(spacing: 8) {
                Text(sessionID)
                    .font(Theme.mono(24))
                    .foregroundStyle(Theme.bone)
                    .tracking(2)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = payload
                        Haptics.success()
                        didCopy = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { didCopy = false }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: didCopy ? DesignLabels.iconCopied : DesignLabels.iconCopy)
                            Text(didCopy ? DesignLabels.copied : DesignLabels.copyLink)
                        }
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.bone)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if let url = URL(string: payload) {
                        ShareLink(item: url) {
                            HStack(spacing: 6) {
                                Image(systemName: DesignLabels.iconShare)
                                Text(DesignLabels.share)
                            }
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.bone)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .liquidGlass()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("host_qr_panel")
    }
}

#Preview {
    ZStack {
        LeopardWallpaperView()
        QRCodePanelView(
            payload: "https://all-hands-on-deck.web.app/join?code=M3F-2P",
            sessionID: "AHOD · M3F-2P"
        )
    }
}
