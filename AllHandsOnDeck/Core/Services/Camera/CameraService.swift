import AVFoundation
import CoreMedia
import UIKit

@MainActor
final class CameraService: NSObject, ObservableObject {
    enum AuthorizationState {
        case notDetermined, authorized, denied
    }

    enum LensType: String, CaseIterable {
        case ultraWide, wide, tele
        var deviceType: AVCaptureDevice.DeviceType {
            switch self {
            case .ultraWide: return .builtInUltraWideCamera
            case .wide:      return .builtInWideAngleCamera
            case .tele:      return .builtInTelephotoCamera
            }
        }
        var label: String {
            switch self {
            case .ultraWide: return "0.5×"
            case .wide:      return "1×"
            case .tele:      return "Tel"
            }
        }
    }

    /// Three-state HD policy. `.off` = standard photo size, `.half` = roughly half
    /// the sensor's max (good middle-ground for older phones), `.full` = device max
    /// (48 MP class on iPhone 14 Pro and newer).
    enum HighResMode: String, CaseIterable {
        case off, half, full

        /// Short German label shown in the transient capsule and settings row.
        var label: String {
            switch self {
            case .off:  return "Standard"
            case .half: return "HD"
            case .full: return "HD+ (max)"
            }
        }
    }

    @Published private(set) var authorization: AuthorizationState = .notDetermined
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var zoomFactor: CGFloat = 1.0
    @Published private(set) var isFrontCamera: Bool = false
    @Published private(set) var isTorchOn: Bool = false
    @Published private(set) var maxZoom: CGFloat = 10.0
    @Published private(set) var currentLens: LensType = .wide
    @Published private(set) var availableLenses: [LensType] = [.wide]
    @Published private(set) var highResMode: HighResMode = .off
    @Published private(set) var supportsFullRes: Bool = false
    @Published private(set) var maxDimensions = CMVideoDimensions(width: 0, height: 0)
    /// Wide-equivalent zoom shown to the user (0.5–10). Tracks across lens switches.
    @Published private(set) var virtualZoom: CGFloat = 1.0
    /// Optical zoom of the tele lens relative to wide, computed from field-of-view on first use.
    @Published private(set) var teleEquivalentZoom: CGFloat = 3.0

    /// Derived for legacy bindings — anything observing `highResMode` re-renders too.
    var isHighResEnabled: Bool { highResMode != .off }

    /// Modes the UI may offer: `.full` is hidden on devices that lack a 48 MP-class
    /// sensor (anything older than iPhone 14 Pro). `.off → .half` is universal.
    var allowedHighResModes: [HighResMode] {
        supportsFullRes ? [.off, .half, .full] : [.off, .half]
    }

    var minVirtualZoom: CGFloat { availableLenses.contains(.ultraWide) ? 0.5 : 1.0 }

    // Stored on sessionQueue; used to derive teleEquivalentZoom via FOV comparison.
    nonisolated(unsafe) private var wideFovDegrees: Float = 0

    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private var currentInput: AVCaptureDeviceInput?

    private let sessionQueue = DispatchQueue(label: "app.captainleopard.allhands.camera.session")
    private let videoOutputQueue = DispatchQueue(label: "app.captainleopard.allhands.camera.video")
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    private var photoContinuation: CheckedContinuation<Data, Error>?

    private final class FramePipeline {
        let lock = NSLock()
        var handler: (@Sendable (Data) -> Void)?
        var lastEmit: Date = .distantPast
        let minInterval: TimeInterval = 1.0 / 3.0
        var isFrontCamera: Bool = false
    }
    nonisolated(unsafe) private let pipeline = FramePipeline()
    // CIContext is documented thread-safe; nonisolated(unsafe) lets the nonisolated
    // captureOutput delegate method touch it without crossing the @MainActor boundary.
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    var previewFrameConsumer: (@Sendable (Data) -> Void)? {
        didSet {
            pipeline.lock.lock()
            pipeline.handler = previewFrameConsumer
            pipeline.lastEmit = .distantPast
            pipeline.lock.unlock()
        }
    }

    // MARK: - Init

    override init() {
        super.init()
        // Resolve already-granted authorization synchronously so the first SwiftUI
        // render sees .authorized and can skip the priming screen entirely.
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:           authorization = .authorized
        case .denied, .restricted:  authorization = .denied
        default:                    break
        }
    }

    // MARK: - Permissions

    func requestPermissionIfNeeded() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorization = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorization = granted ? .authorized : .denied
        default:
            authorization = .denied
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard authorization == .authorized else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.configureSession(position: .back)
            }
            if !self.session.isRunning { self.session.startRunning() }
            Task { @MainActor in self.isRunning = self.session.isRunning }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            Task { @MainActor in self.isRunning = false }
        }
    }

    // MARK: - Configuration

    private nonisolated func configureSession(position: AVCaptureDevice.Position,
                                              lens: LensType = .wide) {
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let old = currentInput {
            session.removeInput(old)
            currentInput = nil
        }

        guard let device = AVCaptureDevice.default(lens.deviceType, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            Task { @MainActor in self.lastError = "Kamera nicht verfügbar." }
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        currentInput = input

        let cappedMax = min(device.maxAvailableVideoZoomFactor, 10.0)

        // Discover which lenses exist on this device side.
        var found: [LensType] = []
        for l in LensType.allCases where AVCaptureDevice.default(l.deviceType, for: .video, position: position) != nil {
            found.append(l)
        }

        if session.outputs.isEmpty {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                photoOutput.maxPhotoQualityPrioritization = .quality
            }
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        }

        // Field-of-view for deriving the tele optical multiplier without hardcoding per device.
        let fov = device.activeFormat.videoFieldOfView
        if lens == .wide { wideFovDegrees = fov }
        let computedTeleEq: CGFloat? = (lens == .tele && wideFovDegrees > 0)
            ? max(2.0, CGFloat(wideFovDegrees / fov))
            : nil

        // Virtual zoom this lens represents at device factor 1.0.
        let nativeVirtual: CGFloat
        switch lens {
        case .ultraWide: nativeVirtual = 0.5
        case .wide:      nativeVirtual = 1.0
        case .tele:      nativeVirtual = computedTeleEq ?? 3.0
        }

        // Inspect the active format's supported photo dimensions to decide capability.
        // iPhone 14 Pro / 15 / 16 / 17 expose dimensions ≥ 7000 wide (8064 × 6048 = 48 MP).
        let supportedDims = device.activeFormat.supportedMaxPhotoDimensions
        let largest = supportedDims.max(by: { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) })
        let supportsFull = supportedDims.contains(where: { $0.width >= 7000 })
        let activeDims = largest ?? CMVideoDimensions(width: 0, height: 0)

        // Reset photo dimensions to the format default whenever we reconfigure —
        // any prior `.half` / `.full` selection is bound to the old lens.
        if !supportedDims.isEmpty, let first = supportedDims.first {
            photoOutput.maxPhotoDimensions = first
        }

        session.commitConfiguration()

        Task { @MainActor in
            self.maxZoom = cappedMax
            self.currentLens = lens
            if position == .back { self.availableLenses = found }
            self.supportsFullRes = supportsFull
            self.maxDimensions = activeDims
            self.highResMode = .off
            self.virtualZoom = nativeVirtual
            if let t = computedTeleEq { self.teleEquivalentZoom = t }
        }
    }

    // MARK: - Camera controls

    func setZoom(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentInput?.device else { return }
            let clamped = max(1.0, min(factor, min(device.maxAvailableVideoZoomFactor, 10.0)))
            try? device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            Task { @MainActor in self.zoomFactor = clamped }
        }
    }

    func flipCamera() {
        let newPosition: AVCaptureDevice.Position = isFrontCamera ? .back : .front
        let front = newPosition == .front
        sessionQueue.async { [weak self] in
            guard let self else { return }
            // configureSession resets highResMode/zoom-related published state.
            self.configureSession(position: newPosition, lens: .wide)
            self.pipeline.lock.lock()
            self.pipeline.isFrontCamera = front
            self.pipeline.lock.unlock()
            Task { @MainActor in
                self.isFrontCamera = front
                self.zoomFactor = 1.0
                self.virtualZoom = 1.0
                if front { self.isTorchOn = false }
            }
        }
    }

    func switchLens(_ lens: LensType) {
        guard !isFrontCamera, availableLenses.contains(lens) else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureSession(position: .back, lens: lens)
            // Disable torch when switching lenses — state may not carry over.
            if let device = self.currentInput?.device, !device.hasTorch {
                Task { @MainActor in self.isTorchOn = false }
            }
            Task { @MainActor in self.zoomFactor = 1.0 }
            // virtualZoom is set by configureSession's Task to the lens's nativeVirtual.
        }
    }

    /// Continuous zoom spanning all lenses. `factor` is wide-equivalent (0.5 = ultraWide native,
    /// 1.0 = wide native, teleEquivalentZoom = tele native). Switches lenses automatically when
    /// crossing their native thresholds.
    func smartZoom(_ factor: CGFloat) {
        guard !isFrontCamera else {
            setZoom(factor)
            virtualZoom = max(1.0, factor)
            return
        }
        let lo = minVirtualZoom
        let clamped = max(lo, min(factor, 10.0))

        let targetLens: LensType
        let deviceFactor: CGFloat

        if clamped < 1.0 && availableLenses.contains(.ultraWide) {
            // 0.5× virtual → ultraWide at device 1.0; 1.0× → ultraWide at device 2.0
            targetLens = .ultraWide
            deviceFactor = max(1.0, clamped / 0.5)
        } else if clamped >= teleEquivalentZoom * 0.85 && availableLenses.contains(.tele) {
            // Enter tele just before its native zoom to feel seamless
            targetLens = .tele
            deviceFactor = max(1.0, clamped / teleEquivalentZoom)
        } else {
            targetLens = .wide
            deviceFactor = max(1.0, clamped)
        }

        if targetLens != currentLens { switchLens(targetLens) }
        setZoom(deviceFactor)
        virtualZoom = clamped
    }

    /// Apply a tri-state HD mode. `.full` is silently capped to `.half` on devices
    /// that don't expose a 48 MP-class sensor — UI hides `.full` for those, but we
    /// also gate it here so a stale binding can't corrupt state.
    func setHighResMode(_ mode: HighResMode) {
        let resolved: HighResMode = (mode == .full && !supportsFullRes) ? highResMode : mode
        guard resolved != highResMode else { return }
        highResMode = resolved
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentInput?.device else { return }
            let dims = device.activeFormat.supportedMaxPhotoDimensions

            // iOS 17 deployment target guarantees `supportedMaxPhotoDimensions`. If a
            // device returned an empty list, treat HD as a no-op rather than calling
            // the deprecated boolean API.
            guard !dims.isEmpty else { return }

            let sortedAscending = dims.sorted { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) }
            let smallest = sortedAscending.first!
            let largest = sortedAscending.last!

            let target: CMVideoDimensions
            switch resolved {
            case .off:
                target = smallest
            case .full:
                target = largest
            case .half:
                // Pick the supported dimension whose width is closest to half of largest.
                let half = Int(largest.width) / 2
                target = sortedAscending.min(by: {
                    abs(Int($0.width) - half) < abs(Int($1.width) - half)
                }) ?? largest
            }

            self.session.beginConfiguration()
            self.photoOutput.maxPhotoDimensions = target
            self.session.commitConfiguration()
        }
    }

    /// Cycle through the device's allowed HD modes — used by the icon button.
    func cycleHighResMode() {
        let modes = allowedHighResModes
        guard !modes.isEmpty else { return }
        let idx = modes.firstIndex(of: highResMode) ?? 0
        let next = modes[(idx + 1) % modes.count]
        setHighResMode(next)
    }

    func toggleTorch() {
        guard !isFrontCamera else { return }
        sessionQueue.async { [weak self] in
            guard let self,
                  let device = self.currentInput?.device,
                  device.hasTorch else { return }
            try? device.lockForConfiguration()
            let newMode: AVCaptureDevice.TorchMode = device.torchMode == .on ? .off : .on
            if device.isTorchModeSupported(newMode) { device.torchMode = newMode }
            device.unlockForConfiguration()
            let on = device.torchMode == .on
            Task { @MainActor in self.isTorchOn = on }
        }
    }

    // MARK: - Capture

    func capturePhoto() async throws -> Data {
        if photoContinuation != nil {
            throw NSError(domain: "Camera", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Capture already in progress."])
        }
        let angle = currentVideoRotationAngle()
        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            sessionQueue.async { [weak self] in
                guard let self else { return }
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .quality
                if let connection = self.photoOutput.connection(with: .video),
                   connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func currentVideoRotationAngle() -> CGFloat {
        // iOS 17 replaced AVCaptureVideoOrientation with degrees-from-natural-portrait.
        switch UIDevice.current.orientation {
        case .landscapeLeft:      return 0    // was .landscapeRight
        case .landscapeRight:     return 180  // was .landscapeLeft
        case .portraitUpsideDown: return 270
        default:                  return 90   // portrait
        }
    }

    func captureBurst(count: Int = 5, delay: TimeInterval = 0.35) async -> [Data] {
        var results: [Data] = []
        results.reserveCapacity(count)
        for _ in 0..<count {
            do {
                let d = try await capturePhoto()
                results.append(d)
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                continue
            }
        }
        return results
    }
}

// MARK: - Photo capture delegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        let result: Result<Data, NSError>
        if let error {
            result = .failure(error as NSError)
        } else if let data = photo.fileDataRepresentation() {
            result = .success(data)
        } else {
            result = .failure(NSError(domain: "Camera", code: -3))
        }
        Task { @MainActor in
            let cont = self.photoContinuation
            self.photoContinuation = nil
            switch result {
            case .success(let d): cont?.resume(returning: d)
            case .failure(let e): cont?.resume(throwing: e)
            }
        }
    }
}

// MARK: - Video frame delegate (preview streaming)

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        pipeline.lock.lock()
        let handler = pipeline.handler
        let last = pipeline.lastEmit
        let now = Date()
        let due = handler != nil && now.timeIntervalSince(last) >= pipeline.minInterval
        if due { pipeline.lastEmit = now }
        let front = pipeline.isFrontCamera
        pipeline.lock.unlock()

        guard due, let handler else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let targetWidth: CGFloat = 640
        let scale = targetWidth / ci.extent.width
        // Front camera sensor output is mirrored; .leftMirrored gives natural portrait selfie.
        // .oriented() bakes the rotation into the CIImage graph so jpegRepresentation renders
        // correctly without needing an intermediate CGImage pixel buffer.
        let cgOrientation: CGImagePropertyOrientation = front ? .leftMirrored : .right
        let scaled = ci
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .oriented(cgOrientation)
        let colorSpace = scaled.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let opts: [CIImageRepresentationOption: Any] = [
            .init(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.5
        ]
        guard let jpeg = ciContext.jpegRepresentation(of: scaled, colorSpace: colorSpace,
                                                      options: opts) else { return }

        handler(jpeg)
    }
}
