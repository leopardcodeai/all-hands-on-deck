import SwiftUI

struct HostSessionView: View {
    @StateObject private var vm: HostSessionViewModel
    @State private var showQR: Bool = true
    @State private var showSettings: Bool = false
    @State private var baseZoom: CGFloat = 1.0
    @State private var showZoomLabel: Bool = false
    @State private var zoomHideTask: Task<Void, Never>? = nil
    let onSessionCreated: (String) -> Void

    init(hostName: String, allowWebJoin: Bool = false, onSessionCreated: @escaping (String) -> Void) {
        _vm = StateObject(wrappedValue: HostSessionViewModel(
            hostName: hostName,
            allowWebJoin: allowWebJoin
        ))
        self.onSessionCreated = onSessionCreated
    }

    var body: some View {
        ZStack {
            // Camera preview, safe-grid overlay, or permission gate — each observes
            // CameraService directly so only this branch re-renders on camera changes.
            CameraAuthBranch(
                camera: vm.camera,
                onMagnifyChanged: { scale in
                    vm.camera.setZoom(baseZoom * scale)
                    flashZoomLabel()
                },
                onMagnifyEnded: { scale in
                    baseZoom = min(max(1.0, baseZoom * scale), vm.camera.maxZoom)
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
                // Observes camera.zoomFactor directly — parent doesn't re-render during pinch.
                ZoomLabelView(camera: vm.camera, visible: showZoomLabel)
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
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await vm.onAppear()
            onSessionCreated(vm.session.id)
        }
        .onDisappear { vm.onDisappear() }
        .alert("Hinweis", isPresented: .init(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Session abgelaufen", isPresented: .init(
            get: { vm.didExpire },
            set: { _ in }
        )) {
            Button("Schließen") { dismiss() }
        } message: {
            Text("Sessions enden automatisch nach Ablauf der TTL — kein Speichern, keine Accounts, keine Spuren.")
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showQR)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showSettings)
    }

    // MARK: - Chrome

    @Environment(\.dismiss) private var dismiss

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

            StatusPill(
                label: vm.statusLabel,
                systemImage: "dot.radiowaves.left.and.right",
                tint: vm.transportStatus == .connected || vm.transportStatus == .advertising
                    ? Theme.signal
                    : Theme.amber
            )

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .heavy))
                Text("\(vm.participants.count)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(Theme.bone)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

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

            // Torch + flip — observe camera directly so only these buttons re-render.
            CameraButtons(camera: vm.camera, onFlip: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { baseZoom = 1.0 }
                vm.camera.flipCamera()
            })

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
                Text("Anfrage von der Crew — bestätige in den Einstellungen.")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.gold)
                    .clipShape(Capsule())
            }

            LensSelectorView(camera: vm.camera, onSelect: { lens in
                withAnimation(.spring(response: 0.25)) { baseZoom = 1.0 }
                vm.camera.switchLens(lens)
            })

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

    private var settingsSheet: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("Timer")
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
                Text("Wer darf auslösen?")
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
                    Text("5 Aufnahmen, KI wählt die beste.")
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

            ParticipantListView(
                participants: vm.participants,
                pendingRequestIDs: vm.pendingCaptureRequests,
                onApprove: { id in Task { await vm.approve(participantID: id) } },
                onDeny: { id in Task { await vm.deny(participantID: id) } }
            )

            PrimaryButton(title: "Schließen", style: .ghost) {
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
}

// MARK: - Camera sub-views
// Each holds @ObservedObject var camera so only it re-renders on camera changes,
// not the full HostSessionView body.

private struct CameraAuthBranch: View {
    @ObservedObject var camera: CameraService
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
                SafeGridOverlayView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        } else if camera.authorization == .denied {
            PermissionView {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } else {
            Color.black.ignoresSafeArea()
        }
    }
}

private struct ZoomLabelView: View {
    @ObservedObject var camera: CameraService
    let visible: Bool

    var body: some View {
        if visible {
            Text(String(format: "%.1f×", camera.zoomFactor))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Theme.gold, in: Capsule())
                .transition(.scale.combined(with: .opacity))
                .padding(.bottom, 4)
        }
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
            }
            Button { onFlip() } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.bone)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct LensSelectorView: View {
    @ObservedObject var camera: CameraService
    let onSelect: (CameraService.LensType) -> Void

    var body: some View {
        if !camera.isFrontCamera && camera.availableLenses.count > 1 {
            HStack(spacing: 6) {
                ForEach(camera.availableLenses, id: \.self) { lens in
                    Button { onSelect(lens) } label: {
                        Text(lens.label)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(camera.currentLens == lens ? .black : Theme.bone)
                            .frame(width: 44, height: 32)
                            .background(
                                camera.currentLens == lens
                                    ? AnyShapeStyle(Theme.goldShine)
                                    : AnyShapeStyle(.ultraThinMaterial),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct HighResRow: View {
    @ObservedObject var camera: CameraService

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.aperture")
                .foregroundStyle(camera.isHighResEnabled ? Theme.gold : Theme.mist)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hohe Auflösung (48 MP)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.bone)
                Text("Maximale Auflösung — langsamere Verarbeitung.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.mist)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { camera.isHighResEnabled },
                set: { _ in camera.toggleHighRes() }
            ))
            .labelsHidden()
            .tint(Theme.gold)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
