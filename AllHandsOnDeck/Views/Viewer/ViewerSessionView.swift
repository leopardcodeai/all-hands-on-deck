import SwiftUI

struct ViewerSessionView: View {
    @StateObject private var vm: ViewerSessionViewModel
    @State private var crewOpen = false

    init(session: PhotoSession, displayName: String) {
        _vm = StateObject(wrappedValue: ViewerSessionViewModel(
            session: session, displayName: displayName
        ))
    }

    var body: some View {
        ZStack {
            Theme.oceanFog.ignoresSafeArea()

            // Live preview slot. Shows mock placeholder until step 2 streams real
            // frames from the host.
            previewLayer
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.5), .clear, .black.opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar.padding(.horizontal, 16).padding(.top, 8)
                Spacer()
                bottomBar.padding(.horizontal, 16).padding(.bottom, 24)
            }

            CountdownOverlayView(
                state: vm.countdown.state,
                remainingSeconds: vm.countdown.remainingSeconds
            )

            if let photo = vm.finalPhoto {
                finalOverlay(photo)
                    .transition(.opacity)
            }

            switch vm.status {
            case .connecting: connectingOverlay
            case .ended:      endedOverlay
            case .lost:       statusOverlay(symbol: "wifi.exclamationmark",
                                             title: "Connection lost",
                                             subtitle: "Captain is out of range. Try again from the Nearby list.")
            case .notFound:   statusOverlay(symbol: "questionmark.circle",
                                             title: "Session not found",
                                             subtitle: "Make sure both devices are connected and the app is open.")
            case .connected:  EmptyView()
            }

            crewPanel
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: crewOpen)
    }

    @ViewBuilder
    private var previewLayer: some View {
        if let img = vm.latestPreviewImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            // Mock placeholder until streaming is wired (Step 2).
            ZStack {
                Theme.abyss
                VStack(spacing: 16) {
                    Image(systemName: "camera.metering.matrix")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(Theme.gold)
                    Text("Waiting for Captain's framing…")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.mist)
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.bone)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            StatusPill(label: vm.status == .connected ? "CONNECTED" : "CONNECTING",
                       systemImage: "antenna.radiowaves.left.and.right",
                       tint: vm.status == .connected ? Theme.signal : Theme.amber)

            Spacer()

            Text(vm.session.id)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.bone)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())

            Button {
                crewOpen = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.bone)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Crew")
        }
    }

    @ViewBuilder
    private var crewPanel: some View {
        if crewOpen {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { crewOpen = false }
                .transition(.opacity)
        }

        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                Capsule()
                    .fill(Theme.mist.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                Text("Crew")
                    .font(Theme.display(20))
                    .foregroundStyle(Theme.bone)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 0) {
                        let participants = vm.session.participants
                        if participants.isEmpty {
                            Text("No crew yet — waiting for the captain's manifest…")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.mist)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 20)
                                .padding(.horizontal, 16)
                        } else {
                            ForEach(participants) { p in
                                HStack(spacing: 12) {
                                    Text(leadingEmoji(p.displayName) ?? "🏴‍☠️")
                                        .font(.system(size: 22))
                                    Text(p.displayName)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.bone)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(crewConnectionIcon(p))
                                        .font(.system(size: 16))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                Divider().opacity(0.15)
                            }
                        }
                    }
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.4)

                PrimaryButton(title: "Close", style: .secondary) { crewOpen = false }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(white: 0.12))
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .offset(y: crewOpen ? 0 : UIScreen.main.bounds.height)
        .transition(.move(edge: .bottom))
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if vm.status == .connected && !vm.countdown.state.isActive {
                ReactionPickerView { r in
                    Task { await vm.sendReaction(r) }
                }
            }
            if vm.canTrigger && !vm.countdown.state.isActive {
                // Mirror the webapp: when everyone can fire, show Timer + Now
                // side-by-side. Otherwise (viewersCanRequest) show one Request button.
                if vm.canTriggerNow {
                    HStack(spacing: 10) {
                        PrimaryButton(title: vm.triggerLabel, systemImage: "timer", style: .primary) {
                            Task { await vm.tapTrigger() }
                        }
                        PrimaryButton(title: "Now", systemImage: "bolt.fill", style: .secondary) {
                            Task { await vm.tapTriggerNow() }
                        }
                    }
                } else {
                    PrimaryButton(title: vm.triggerLabel, systemImage: "camera.fill", style: .primary) {
                        Task { await vm.tapTrigger() }
                    }
                }
            } else if vm.countdown.state.isActive {
                Text("Hold still — smile!")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.bone)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var connectingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(Theme.gold)
                Text("Connecting to session…")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.bone)
            }
        }
    }

    private func statusOverlay(symbol: String, title: String, subtitle: String) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.gold)
                Text(title)
                    .font(Theme.display(22))
                    .foregroundStyle(Theme.bone)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.mist)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                PrimaryButton(title: "Close", style: .secondary) { dismiss() }
                    .padding(.horizontal, 32)
            }
        }
    }

    private var endedOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.gold)
                Text("Session ended")
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.bone)
                PrimaryButton(title: "Close", style: .secondary) { dismiss() }
                    .padding(.horizontal, 32)
            }
        }
    }

    @ViewBuilder
    private func finalOverlay(_ photo: CapturedPhoto) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                if let img = photo.uiImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .padding(.horizontal, 16)
                }
                if vm.session.allowFinalPhotoDownload, let img = photo.uiImage {
                    PrimaryButton(title: "Save", systemImage: "square.and.arrow.down", style: .primary) {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        Haptics.success()
                    }
                    .padding(.horizontal, 16)
                }
                PrimaryButton(title: "Back", style: .ghost) { dismiss() }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
    }

    private func leadingEmoji(_ name: String) -> String? {
        guard let m = name.unicodeScalars.first,
              m.properties.isEmoji && m.value > 0x2000 else { return nil }
        return String(name.unicodeScalars.prefix(1).map(Character.init))
    }

    private func crewConnectionIcon(_ p: Participant) -> String {
        if p.role == .host { return "👑" }
        switch p.connectionType {
        case .web: return "🌐"
        case .mock: return "🤖"
        default: return "📱"
        }
    }
}
