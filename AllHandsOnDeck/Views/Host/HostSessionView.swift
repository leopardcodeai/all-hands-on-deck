import SwiftUI

struct HostSessionView: View {
    @StateObject private var vm: HostSessionViewModel
    @State private var showQR: Bool = true
    @State private var showSettings: Bool = false
    @State private var baseZoom: CGFloat = 1.0
    @State private var showZoomLabel: Bool = false
    @State private var zoomHideTask: Task<Void, Never>?
    @AppStorage("camera.showGrid")  private var showGrid: Bool = true
    @AppStorage("camera.showLevel") private var showLevel: Bool = true
    @AppStorage("debug.showOverlays") private var showDebugOverlays = true
    @State private var crewOpen = false
    let onSessionCreated: (String) -> Void

    init(hostName: String, allowWebJoin: Bool = false, onSessionCreated: @escaping (String) -> Void) {
        // Inline directly into StateObject(wrappedValue:) so the @autoclosure wrapper
        // defers evaluation until SwiftUI first presents this view. Extracting to a
        // local `let vm = ...` would evaluate eagerly on every HomeView re-render,
        // creating a throwaway CameraService + transport and causing
        // "Publishing during view updates" faults.
        _vm = StateObject(wrappedValue:
            HostSessionRetention.shared.consume()
                ?? HostSessionViewModel(hostName: hostName, allowWebJoin: allowWebJoin)
        )
        self.onSessionCreated = onSessionCreated
    }

    var body: some View {
        ZStack {
            // Camera preview, safe-grid overlay, or permission gate — each observes
            // CameraService directly so only this branch re-renders on camera changes.
            CameraAuthBranch(
                camera: vm.camera,
                showGrid: showGrid,
                showLevel: showLevel,
                onMagnifyChanged: { scale in
                    vm.camera.smartZoom(baseZoom * scale)
                    flashZoomLabel()
                },
                onMagnifyEnded: { _ in
                    baseZoom = vm.camera.virtualZoom
                }
            )

            // Soft gradient so chrome reads on bright frames.
            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .black.opacity(0.65)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()
                if showQR {
                    QRCodePanelView(payload: vm.qrPayload, sessionID: vm.session.id)
                        .frame(maxWidth: 320)
                        .transition(.scale.combined(with: .opacity))
                        .padding(.bottom, 12)
                }
                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            // Centered floating zoom HUD — observes camera directly so the
            // parent doesn't re-render at gesture rate.
            ZoomLabelView(camera: vm.camera, visible: showZoomLabel)

            if showSettings {
                settingsSheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.height > 60 {
                                    withAnimation { showSettings = false }
                                }
                            }
                    )
            }

            CountdownOverlayView(
                state: vm.countdown.state,
                remainingSeconds: vm.countdown.remainingSeconds
            )

            if !vm.burstCandidates.isEmpty {
                BurstPickerView(
                    candidates: vm.burstCandidates,
                    scores: vm.burstScores,
                    isRanking: vm.isRankingBurst,
                    onPick: { photo in
                        Task { await vm.acceptBurstPick(photo) }
                    },
                    onDiscard: { vm.discardBurst() }
                )
                .transition(.opacity)
            } else if let captured = vm.capturedPhoto {
                resultOverlay(photo: captured)
                    .transition(.opacity)
            }

            // Crew popup backdrop (behind popup so taps on popup don't close it)
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
        .task {
            await vm.onAppear()
            onSessionCreated(vm.session.id)
        }
        .onDisappear {
            // If the session ended on its own (TTL expiry), tear down now.
            // Otherwise park the VM so the captain can briefly drop to Home
            // and resume within 10s without losing the session.
            if vm.didExpire {
                vm.shutdown()
            } else {
                HostSessionRetention.shared.park(vm)
            }
        }
        .alert("Notice", isPresented: .init(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Session expired", isPresented: .init(
            get: { vm.didExpire },
            set: { _ in }
        )) {
            Button(DesignLabels.close) { dismiss() }
        } message: {
            Text("Sessions end automatically after TTL — no saving, no accounts, no traces.")
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showQR)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showSettings)
    }

    // MARK: - Chrome

    @Environment(\.dismiss) private var dismiss

    private var crewPopup: some View {
        VStack(spacing: 0) {
            Text(DesignLabels.crew)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(Theme.gold)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    if vm.participants.isEmpty {
                        Text(DesignLabels.noCrewYet)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.mist)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(vm.participants) { p in
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
        }
        .padding(14)
        .frame(width: 260)
        .liquidGlass()
    }

    private func flashZoomLabel() {
        withAnimation(.spring(response: 0.25)) { showZoomLabel = true }
        zoomHideTask?.cancel()
        zoomHideTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.4)) { showZoomLabel = false }
            }
        }
    }

    private var topBar: some View {
        // Two compact rows so nothing clips on narrow iPhones (SE/mini width ≈ 320pt).
        // Row 1: identity + connection state. Row 2: camera-mode chrome.
        VStack(spacing: 8) {
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
                .accessibilityLabel(DesignLabels.back)
                .accessibilityHint("Returns to the home screen")

                StatusPill(
                    label: vm.statusLabel,
                    systemImage: "dot.radiowaves.left.and.right",
                    tint: vm.transportStatus == .connected || vm.transportStatus == .advertising
                        ? Theme.signal
                        : Theme.amber
                )

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { crewOpen.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 12, weight: .heavy))
                            Text("\(vm.participants.count)")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(crewOpen ? .black : Theme.bone)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(crewOpen ? AnyShapeStyle(Theme.goldShine) : AnyShapeStyle(.ultraThinMaterial), in: Capsule())

                Button {
                    withAnimation { showSettings.toggle() }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.bone)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .accessibilityHint("Open timer, permissions, grid and HD options")
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation { showQR.toggle() }
                } label: {
                    Image(systemName: showQR ? "qrcode" : "qrcode.viewfinder")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(showQR ? .black : Theme.bone)
                        .frame(width: 40, height: 40)
                        .background(showQR ? AnyShapeStyle(Theme.goldShine) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showQR ? "Hide QR code" : "Show QR code")
                .accessibilityHint("Lets crew members scan to join the session")

                LensSelectorView(camera: vm.camera, onSelect: { lens in
                    vm.camera.switchLens(lens)
                    switch lens {
                    case .ultraWide: baseZoom = vm.camera.minVirtualZoom
                    case .wide:      baseZoom = 1.0
                    case .tele:      baseZoom = vm.camera.teleEquivalentZoom
                    }
                    flashZoomLabel()
                })

                Spacer()

                HighResButton(camera: vm.camera)

                // Torch + flip — observes camera directly so only these buttons re-render.
                CameraButtons(camera: vm.camera, onFlip: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { baseZoom = 1.0 }
                    vm.camera.flipCamera()
                })
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let toast = vm.visibleReaction {
                ReactionToastView(reaction: toast.reaction, from: toast.from)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let hint = vm.inFrameDetector.status {
                InFrameHintView(status: hint)
                    .transition(.scale.combined(with: .opacity))
            }
            if !vm.pendingCaptureRequests.isEmpty {
                Text("Request from crew — confirm in settings.")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.gold)
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                if vm.countdown.state.isActive {
                    PrimaryButton(title: "Abbrechen", systemImage: "xmark", style: .destructive) {
                        Task { await vm.cancelCountdown() }
                    }
                } else {
                    PrimaryButton(
                        title: String(format: String(localized: "host.startTimer"), vm.session.timerDuration),
                        systemImage: "timer",
                        style: .primary
                    ) {
                        Task { await vm.startCountdown() }
                    }
                    PrimaryButton(title: "Jetzt", systemImage: "camera.fill", style: .secondary) {
                        Task { await vm.captureNow() }
                    }
                }
            }
        }
    }

    private func settingsToggleRow(systemImage: String,
                                   title: String,
                                   subtitle: String,
                                   isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(isOn.wrappedValue ? Theme.gold : Theme.mist)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.bone)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.mist)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.gold)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private var settingsSheet: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                Text(DesignLabels.timer(10))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(Theme.mist)
                TimerPickerView(
                    seconds: Binding(
                        get: { vm.session.timerDuration },
                        set: { vm.setTimerDuration($0) }
                    ),
                    options: [5, 10, 20, 30]
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Who can trigger?")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(Theme.mist)
                TriggerPermissionPickerView(selection: Binding(
                    get: { vm.session.triggerPermission },
                    set: { vm.setTriggerPermission($0) }
                ))
            }

            HStack(spacing: 12) {
                Image(systemName: "burst")
                    .foregroundStyle(vm.burstEnabled ? Theme.gold : Theme.mist)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Best-Shot Burst")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.bone)
                    Text("5 shots, AI picks the best.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.mist)
                }
                Spacer()
                Toggle("", isOn: $vm.burstEnabled)
                    .labelsHidden()
                    .tint(Theme.gold)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            HighResRow(camera: vm.camera)

            settingsToggleRow(
                systemImage: "grid",
                title: "Grid",
                subtitle: "Rule-of-thirds + safe-area frame.",
                isOn: $showGrid
            )
            settingsToggleRow(
                systemImage: "level",
                title: "Level",
                subtitle: "Horizon indicator turns yellow when level.",
                isOn: $showLevel
            )

            ParticipantListView(
                participants: vm.participants,
                pendingRequestIDs: vm.pendingCaptureRequests,
                onApprove: { id in Task { await vm.approve(participantID: id) } },
                onDeny: { id in Task { await vm.deny(participantID: id) } }
            )

            PrimaryButton(title: DesignLabels.close, style: .ghost) {
                withAnimation { showSettings = false }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 8)
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func resultOverlay(photo: CapturedPhoto) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                if let img = photo.uiImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .padding(.horizontal, 16)
                }
                HStack(spacing: 10) {
                    PrimaryButton(title: "Noch einmal", systemImage: "arrow.counterclockwise", style: .secondary) {
                        vm.discardCapture()
                    }
                    PrimaryButton(title: "Speichern", systemImage: "square.and.arrow.down", style: .primary) {
                        savePhoto(photo)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func savePhoto(_ photo: CapturedPhoto) {
        guard let img = photo.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        Haptics.success()
        vm.discardCapture()
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

// MARK: - Camera sub-views
// Each holds @ObservedObject var camera so only it re-renders on camera changes,
// not the full HostSessionView body.

private struct CameraAuthBranch: View {
    @ObservedObject var camera: CameraService
    let showGrid: Bool
    let showLevel: Bool
    let onMagnifyChanged: (CGFloat) -> Void
    let onMagnifyEnded: (CGFloat) -> Void

    var body: some View {
        if camera.authorization == .authorized {
            ZStack {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
                    .gesture(
                        MagnificationGesture()
                            .onChanged { onMagnifyChanged($0) }
                            .onEnded { onMagnifyEnded($0) }
                    )
                if showGrid {
                    SafeGridOverlayView()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                if showLevel {
                    LevelIndicatorView()
                        .allowsHitTesting(false)
                }
            }
            // Fade in once the session is running — hides the brief black frame
            // while AVCaptureSession.startRunning() completes on sessionQueue.
            .opacity(camera.isRunning ? 1 : 0)
            .animation(.easeIn(duration: 0.25), value: camera.isRunning)
        } else if camera.authorization == .denied {
            PermissionView {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } else {
            // .notDetermined — context behind the iOS permission prompt.
            // Apple rejects apps that show only a black screen here; the
            // priming text reinforces NSCameraUsageDescription.
            CameraPrimingView()
        }
    }
}

private struct CameraPrimingView: View {
    var body: some View {
        ZStack {
            Theme.oceanFog.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text("Just a moment…")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.bone)
                Text("AllHandsOnDeck needs camera access so your crew can see what you see.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.mist)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                ProgressView()
                    .tint(Theme.mist)
                    .padding(.top, 4)
            }
        }
    }
}

/// Apple-style centered zoom indicator that fades in during pinch and out 1.5s after.
/// Larger, bolder, yellow — matches the iOS Camera app look.
private struct ZoomLabelView: View {
    @ObservedObject var camera: CameraService
    let visible: Bool

    var body: some View {
        Text(String(format: "%.1f×", camera.virtualZoom))
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.yellow)
            .shadow(color: .black.opacity(0.7), radius: 6, y: 1)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.yellow.opacity(0.5), lineWidth: 1))
            .scaleEffect(visible ? 1.0 : 0.85)
            .opacity(visible ? 1.0 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: visible)
            .allowsHitTesting(false)
    }
}

/// Subtle horizon indicator. Two short bars in the center: a fixed reference
/// and a tilted one that rotates with device roll. Both turn yellow when the
/// device is within ±2° of level — matching iOS Camera's level affordance.
private struct LevelIndicatorView: View {
    @StateObject private var level = LevelService.shared

    var body: some View {
        let isLevel = level.isLevel
        ZStack {
            Capsule()
                .fill(isLevel ? Color.yellow : Color.white.opacity(0.45))
                .frame(width: 44, height: 1)
            Capsule()
                .fill(isLevel ? Color.yellow : Color.white.opacity(0.85))
                .frame(width: 88, height: 1)
                .rotationEffect(.degrees(-level.rollDegrees))
        }
        .shadow(color: .black.opacity(0.6), radius: 2)
        .animation(.easeOut(duration: 0.18), value: isLevel)
        .onAppear { level.start() }
        .onDisappear { level.stop() }
    }
}

private struct CameraButtons: View {
    @ObservedObject var camera: CameraService
    let onFlip: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if !camera.isFrontCamera {
                Button { camera.toggleTorch() } label: {
                    Image(systemName: camera.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(camera.isTorchOn ? .black : Theme.bone)
                        .frame(width: 40, height: 40)
                        .background(
                            camera.isTorchOn ? AnyShapeStyle(Theme.goldShine) : AnyShapeStyle(.ultraThinMaterial),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(camera.isTorchOn ? "Turn off flashlight" : "Turn on flashlight")
            }
            Button { onFlip() } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.bone)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(camera.isFrontCamera ? "Switch to back camera" : "Switch to front camera")
        }
    }
}

/// Apple-style lens picker: a single dark blurred capsule containing all lens
/// options. Active lens is bolder/larger and wrapped in a filled circle that
/// slides smoothly between options via `matchedGeometryEffect`.
private struct LensSelectorView: View {
    @ObservedObject var camera: CameraService
    let onSelect: (CameraService.LensType) -> Void
    @Namespace private var ns

    var body: some View {
        if !camera.isFrontCamera && camera.availableLenses.count > 1 {
            HStack(spacing: 2) {
                ForEach(camera.availableLenses, id: \.self) { lens in
                    let isActive = camera.currentLens == lens
                    Button { onSelect(lens) } label: {
                        ZStack {
                            if isActive {
                                Circle()
                                    .fill(Color.black.opacity(0.55))
                                    .matchedGeometryEffect(id: "lens-bg", in: ns)
                            }
                            Text(label(for: lens, active: isActive))
                                .font(.system(size: isActive ? 13 : 11,
                                              weight: .heavy, design: .rounded))
                                .foregroundStyle(isActive ? Color.yellow : Theme.bone)
                        }
                        .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: lens))
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                }
            }
            .padding(4)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            .animation(.spring(response: 0.3, dampingFraction: 0.75),
                       value: camera.currentLens)
        }
    }

    private func label(for lens: CameraService.LensType, active: Bool) -> String {
        switch lens {
        case .ultraWide: return active ? ".5×" : ".5"
        case .wide:      return active ? "1×"  : "1"
        case .tele:
            let n = max(2, Int(camera.teleEquivalentZoom.rounded()))
            return active ? "\(n)×" : "\(n)"
        }
    }

    private func accessibilityLabel(for lens: CameraService.LensType) -> String {
        switch lens {
        case .ultraWide: return "Ultra-wide lens, half magnification"
        case .wide:      return "Wide lens, one times magnification"
        case .tele:
            let n = max(2, Int(camera.teleEquivalentZoom.rounded()))
            return "Telephoto lens, \(n) times magnification"
        }
    }
}

private struct HighResRow: View {
    @ObservedObject var camera: CameraService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "camera.aperture")
                    .foregroundStyle(camera.highResMode != .off ? Theme.gold : Theme.mist)
                VStack(alignment: .leading, spacing: 2) {
                    Text(DesignLabels.resolution)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.bone)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.mist)
                }
                Spacer()
            }
            Picker(DesignLabels.resolution, selection: Binding(
                get: { camera.highResMode },
                set: { camera.setHighResMode($0) }
            )) {
                ForEach(camera.allowedHighResModes, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private var subtitle: String {
        switch camera.highResMode {
        case .off:  return "Standard — fast and light."
        case .half: return "HD — middle ground, works on older iPhones."
        case .full: return "HD+ — 48 MP, slower processing."
        }
    }
}

/// Compact icon button next to torch/flip — cycles `off → half → full` (the latter
/// only on devices with a 48 MP sensor). Visible in photo mode so power users
/// don't have to open settings to bump quality.
private struct HighResButton: View {
    @ObservedObject var camera: CameraService

    var body: some View {
        Button { camera.cycleHighResMode() } label: {
            VStack(spacing: 0) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 14, weight: .heavy))
                Text(badge)
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(0.5)
            }
            .foregroundStyle(camera.highResMode != .off ? .black : Theme.bone)
            .frame(width: 40, height: 40)
            .background(
                camera.highResMode != .off
                    ? AnyShapeStyle(Theme.goldShine)
                    : AnyShapeStyle(.ultraThinMaterial),
                in: Circle()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resolution: \(accessibleName)")
        .accessibilityHint("Tap to cycle through resolution modes")
    }

    private var badge: String {
        switch camera.highResMode {
        case .off:  return "SD"
        case .half: return "HD"
        case .full: return "48"
        }
    }

    private var accessibleName: String {
        switch camera.highResMode {
        case .off:  return "Standard"
        case .half: return "High definition"
        case .full: return "48 megapixel"
        }
    }
}
