import SwiftUI

enum ViewerPreviewLayout {
    static let livePreviewContentMode: ContentMode = .fit
}

struct ViewerSessionView: View {
    @StateObject private var vm: ViewerSessionViewModel
    @State private var crewOpen = false
    @AppStorage("debug.showOverlays") private var showDebugOverlays = true

    init(session: PhotoSession, displayName: String) {
        _vm = StateObject(wrappedValue: ViewerSessionViewModel(
            session: session, displayName: displayName
        ))
    }

    var body: some View {
        ZStack {
            LeopardWallpaperView()

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
                bottomBar.padding(.horizontal, 16).padding(.bottom, 12)
            }

            CountdownOverlayView(
                state: vm.countdownState,
                remainingSeconds: vm.countdownRemaining
            )

            if let photo = vm.finalPhoto {
                finalOverlay(photo)
                    .transition(.opacity)
            }

            switch vm.status {
            case .connecting: connectingOverlay
            case .ended:      endedOverlay
            case .lost:       statusOverlay(symbol: "wifi.exclamationmark",
                                             title: DesignLabels.connectionLost,
                                             subtitle: DesignLabels.connectionLostHint)
            case .notFound:   statusOverlay(symbol: "questionmark.circle",
                                             title: DesignLabels.sessionNotFound,
                                             subtitle: DesignLabels.sessionNotFoundHint)
            case .connected:  EmptyView()
            }

            // Crew popup backdrop
            if crewOpen {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { crewOpen = false } }
                    .transition(.opacity)
            }

            // Crew popup
            if crewOpen {
                crewPopup
                    .transition(.scale.combined(with: .opacity))
            }

            if showDebugOverlays {
                DebugOverlayView()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: crewOpen)
    }

    @ViewBuilder
    private var previewLayer: some View {
        Color.clear
            .overlay {
                if let img = vm.latestPreviewImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: ViewerPreviewLayout.livePreviewContentMode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.abyss)
                } else {
                    ZStack {
                        Theme.abyss
                        VStack(spacing: 16) {
                            Image(systemName: "camera.metering.matrix")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundStyle(Theme.gold)
                            Text(DesignLabels.waitingForFraming)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.mist)
                        }
                    }
                }
            }
    }

    @Environment(\.dismiss) private var dismiss

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: DesignLabels.iconBack)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.bone)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            StatusPill(
                label: vm.status == .connected ? DesignLabels.statusConnected : DesignLabels.statusConnecting,
                systemImage: DesignLabels.iconStatus,
                tint: vm.status == .connected ? Theme.signal : Theme.amber
            )

            Spacer()

            Text(vm.session.id)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.bone)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { crewOpen.toggle() }
            } label: {
                Image(systemName: DesignLabels.iconCrew)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(crewOpen ? .black : Theme.bone)
                    .frame(width: 40, height: 40)
                    .background(crewOpen ? AnyShapeStyle(Theme.goldShine) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(DesignLabels.crew)
        }
    }

    private var crewPopup: some View {
        VStack(spacing: 0) {
            Text(DesignLabels.crew)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(Theme.gold)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    let participants = vm.session.participants
                    if participants.isEmpty {
                        Text(DesignLabels.noCrewYet)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.mist)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(participants) { p in
                            HStack(spacing: 10) {
                                Text(leadingEmoji(p.displayName) ?? "🏴‍☠️")
                                    .font(.system(size: 18))
                                Text(p.displayName)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.bone)
                                    .lineLimit(1)
                                Spacer()
                                Text(crewConnectionIcon(p))
                                    .font(.system(size: 14))
                            }
                            .padding(.vertical, 8)
                            Divider().opacity(0.15)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)

            PrimaryButton(title: DesignLabels.close, style: .secondary) {
                withAnimation { crewOpen = false }
            }
            .padding(.top, 8)
        }
        .padding(14)
        .frame(width: 260)
        .liquidGlass()
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if vm.status == .connected && !vm.countdownState.isActive {
                ReactionPickerView { r in
                    Task { await vm.sendReaction(r) }
                }
            }
            if vm.canTrigger && !vm.countdownState.isActive {
                if vm.canTriggerNow {
                    HStack(spacing: 10) {
                        PrimaryButton(title: vm.triggerLabel, systemImage: DesignLabels.iconTimer, style: .primary) {
                            Task { await vm.tapTrigger() }
                        }
                        PrimaryButton(title: DesignLabels.now, systemImage: DesignLabels.iconNow, style: .secondary) {
                            Task { await vm.tapTriggerNow() }
                        }
                    }
                } else {
                    PrimaryButton(title: vm.triggerLabel, systemImage: DesignLabels.iconCamera, style: .primary) {
                        Task { await vm.tapTrigger() }
                    }
                }
            } else if vm.countdownState.isActive {
                Text(DesignLabels.holdStill)
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
                Text(DesignLabels.connectingToSession)
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
                PrimaryButton(title: DesignLabels.close, style: .secondary) { dismiss() }
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
                Text(DesignLabels.sessionEnded)
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.bone)
                PrimaryButton(title: DesignLabels.close, style: .secondary) { dismiss() }
                    .padding(.horizontal, 32)
            }
        }
    }

    @ViewBuilder
    private func finalOverlay(_ photo: CapturedPhoto) -> some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 14) {
                if let img = photo.uiImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .padding(.horizontal, 16)
                }
                if vm.session.allowFinalPhotoDownload, let img = photo.uiImage {
                    PrimaryButton(title: DesignLabels.save, systemImage: DesignLabels.iconSave, style: .primary) {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        Haptics.success()
                    }
                    .padding(.horizontal, 16)
                }
                PrimaryButton(title: DesignLabels.backToPreview, style: .ghost) { vm.clearFinalPhoto() }
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
