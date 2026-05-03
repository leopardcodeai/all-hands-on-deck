import SwiftUI

/// Shown when the host hasn't yet granted camera access.
struct PermissionView: View {
    var onRequest: () -> Void

    var body: some View {
        ZStack {
            Theme.oceanFog.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text("Kamera-Zugriff benötigt")
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.bone)
                Text("Damit deine Crew sehen kann, was die Kamera sieht, brauchen wir Zugriff auf die iPhone-Kamera.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.mist)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                PrimaryButton(title: DesignLabels.allowAccess, systemImage: "checkmark.shield.fill") {
                    onRequest()
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
    }
}
