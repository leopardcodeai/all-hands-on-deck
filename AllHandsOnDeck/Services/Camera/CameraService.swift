import AVFoundation
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

    @Published private(set) var authorization: AuthorizationState = .notDetermined
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var zoomFactor: CGFloat = 1.0
    @Published private(set) var isFrontCamera: Bool = false
    @Published private(set) var isTorchOn: Bool = false
    @Published private(set) var maxZoom: CGFloat = 10.0
    @Published private(set) var currentLens: LensType = .wide
    @Published private(set) var availableLenses: [LensType] = [.wide]
    @Published private(set) var isHighResEnabled: Bool = false

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
    nonisolated(unsafe) private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    var previewFrameConsumer: (@Sendable (Data) -> Void)? {
        didSet {
            pipeline.lock.lock()
            pipeline.handler = previewFrameConsumer
            pipeline.lastEmit = .distantPast
            pipeline.lock.unlock()
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
        for l in LensType.allCases {
            if AVCaptureDevice.default(l.deviceType, for: .video, position: position) != nil {
                found.append(l)
            }
        }

        Task { @MainActor in
            self.maxZoom = cappedMax
            self.currentLens = lens
            if position == .back { self.availableLenses = found }
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

        session.commitConfiguration()
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
            self.configureSession(position: newPosition, lens: .wide)
            self.pipeline.lock.lock()
            self.pipeline.isFrontCamera = front
            self.pipeline.lock.unlock()
            Task { @MainActor in
                self.isFrontCamera = front
                self.zoomFactor = 1.0
                self.isHighResEnabled = false
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
            Task { @MainActor in
                self.zoomFactor = 1.0
                self.isHighResEnabled = false
            }
        }
    }

    func toggleHighRes() {
        let enable = !isHighResEnabled
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentInput?.device else { return }
            let dims = device.activeFormat.supportedMaxPhotoDimensions
            guard !dims.isEmpty else { return }
            let target = enable
                ? dims.max(by: { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) })
                : dims.min(by: { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) })
            guard let target else { return }
            self.session.beginConfiguration()
            self.photoOutput.maxPhotoDimensions = target
            self.session.commitConfiguration()
            Task { @MainActor in self.isHighResEnabled = enable }
        }
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
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = ciContext.createCGImage(scaled, from: scaled.extent) else { return }
        // Front camera sensor output is mirrored; .leftMirrored gives natural portrait selfie
        let orientation: UIImage.Orientation = front ? .leftMirrored : .right
        let ui = UIImage(cgImage: cg, scale: 1, orientation: orientation)
        guard let jpeg = ui.jpegData(compressionQuality: 0.5) else { return }

        handler(jpeg)
    }
}

