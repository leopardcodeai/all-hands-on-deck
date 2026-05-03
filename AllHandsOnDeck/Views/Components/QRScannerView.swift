import SwiftUI
@preconcurrency import AVFoundation
import UIKit

/// SwiftUI wrapper around AVCaptureSession + AVCaptureMetadataOutput for QR.
///
/// `onResult` is called once with the first decoded string (we stop the
/// session immediately after to avoid duplicate triggers).
struct QRScannerView: UIViewControllerRepresentable {
    let onResult: (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onResult = onResult
        vc.onCancel = onCancel
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}
}

final class ScannerVC: UIViewController {
    var onResult: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "qr.scanner.session")
    private var hasReported = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureUI()
        Task { await configureCaptureIfPermitted() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning { captureSession.stopRunning() }
        }
    }

    // MARK: - Setup

    private func configureUI() {
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("Cancel", for: .normal)
        cancelBtn.setTitleColor(.white, for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.addTarget(self, action: #selector(tappedCancel), for: .touchUpInside)
        view.addSubview(cancelBtn)
        NSLayoutConstraint.activate([
            cancelBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            cancelBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18)
        ])

        let hint = UILabel()
        hint.text = "Hold QR code in frame"
        hint.textColor = .white
        hint.font = .systemFont(ofSize: 14, weight: .semibold)
        hint.textAlignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    @objc private func tappedCancel() {
        onCancel?()
    }

    private func configureCaptureIfPermitted() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await setupSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { await setupSession() } else { showDenied() }
        default:
            showDenied()
        }
    }

    @MainActor
    private func setupSession() async {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showDenied()
            return
        }

        captureSession.beginConfiguration()
        if captureSession.canAddInput(input) { captureSession.addInput(input) }

        let metadata = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadata) {
            captureSession.addOutput(metadata)
            metadata.setMetadataObjectsDelegate(self, queue: .main)
            metadata.metadataObjectTypes = [.qr]
        }
        captureSession.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        self.previewLayer = preview

        sessionQueue.async { [captureSession] in
            captureSession.startRunning()
        }
    }

    @MainActor
    private func showDenied() {
        let label = UILabel()
        label.text = "Please allow camera access in Settings."
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }
}

extension ScannerVC: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasReported,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let raw = obj.stringValue else { return }
        hasReported = true
        sessionQueue.async { [captureSession] in
            captureSession.stopRunning()
        }
        Haptics.success()
        onResult?(raw)
    }
}
