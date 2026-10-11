import Foundation
import Vision
import CoreImage
import UIKit

/// Runs `VNDetectFaceRectanglesRequest` on a throttled stream of preview JPEGs
/// and converts the result into an `InFrameStatus` verdict.
///
/// We deliberately reuse the existing 3 fps preview pipeline (the same JPEG
/// frames the streaming layer ships) to avoid pulling a second tap off
/// AVCaptureSession.
@MainActor
final class InFrameDetector: ObservableObject {
    @Published private(set) var status: InFrameStatus?

    private let queue = DispatchQueue(label: "app.captainleopard.allhands.vision")
    private var pending = false

    /// Safe-area inset (in normalized 0..1 coords). Faces that touch outside
    /// this margin are flagged as clipped.
    private let safeMargin: CGFloat = 0.06

    /// Throttle: don't run more than once per minInterval seconds.
    private var lastRun: Date = .distantPast
    private let minInterval: TimeInterval = 0.5

    func ingest(jpeg: Data) {
        let now = Date()
        guard !pending, now.timeIntervalSince(lastRun) >= minInterval else { return }
        pending = true
        lastRun = now

        queue.async { [weak self] in
            guard let self else { return }
            let verdict = Self.analyse(jpeg: jpeg, safeMargin: self.safeMargin)
            Task { @MainActor in
                self.status = verdict
                self.pending = false
            }
        }
    }

    func reset() {
        status = nil
    }

    // MARK: - Analysis

    nonisolated private static func analyse(jpeg: Data, safeMargin: CGFloat) -> InFrameStatus {
        guard let ci = CIImage(data: jpeg) else {
            return InFrameStatus(verdict: .noFaces, faceCount: 0, updatedAt: Date())
        }

        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        let handler = VNImageRequestHandler(ciImage: ci, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return InFrameStatus(verdict: .noFaces, faceCount: 0, updatedAt: Date())
        }
        guard let results = request.results, !results.isEmpty else {
            return InFrameStatus(verdict: .noFaces, faceCount: 0, updatedAt: Date())
        }

        // VN coords: origin bottom-left, normalized.
        var clipped = false
        var minX: CGFloat = 1, maxX: CGFloat = 0, minY: CGFloat = 1, maxY: CGFloat = 0

        for face in results {
            let r = face.boundingBox
            if r.minX < safeMargin || r.maxX > 1 - safeMargin
               || r.minY < safeMargin || r.maxY > 1 - safeMargin {
                clipped = true
            }
            minX = min(minX, r.minX); maxX = max(maxX, r.maxX)
            minY = min(minY, r.minY); maxY = max(maxY, r.maxY)
        }

        if clipped {
            return InFrameStatus(verdict: .someClipped, faceCount: results.count, updatedAt: Date())
        }

        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let dx = centerX - 0.5
        let dy = centerY - 0.5

        // Pick the dominant skew direction if it's significant; otherwise
        // declare "all good".
        if abs(dx) > 0.18 && abs(dx) >= abs(dy) {
            return InFrameStatus(
                verdict: dx < 0 ? .skewedLeft : .skewedRight,
                faceCount: results.count,
                updatedAt: Date()
            )
        }
        if abs(dy) > 0.18 {
            // Remember: VN y-up coords. Group center "high in the frame"
            // means dy > 0 → camera is too low.
            return InFrameStatus(
                verdict: dy > 0 ? .tooHigh : .tooLow,
                faceCount: results.count,
                updatedAt: Date()
            )
        }
        return InFrameStatus(verdict: .allInside, faceCount: results.count, updatedAt: Date())
    }
}
