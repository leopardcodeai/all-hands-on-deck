import Foundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Scores a candidate group photo. Higher is better.
///
/// Heuristics for an MVP best-shot pick:
///  - faceCount: more visible faces → better
///  - eyesOpenScore: per-face eye-open confidence (Vision face landmarks)
///  - sharpness: variance of Laplacian on a downscaled grayscale (no motion blur)
///
/// Composite score = w1·faceCount + w2·eyesOpen + w3·sharpness, with weights
/// tuned so that "all eyes open + sharp" beats "more faces but blurry".
struct PhotoScore: Sendable {
    let imageIndex: Int
    let faceCount: Int
    let eyesOpen: Double
    let sharpness: Double
    let composite: Double
}

enum PhotoQualityScorer {
    static func rank(_ jpegBlobs: [Data]) async -> [PhotoScore] {
        await withTaskGroup(of: PhotoScore?.self) { group in
            for (idx, data) in jpegBlobs.enumerated() {
                group.addTask {
                    await score(jpeg: data, index: idx)
                }
            }
            var results: [PhotoScore] = []
            for await s in group {
                if let s { results.append(s) }
            }
            return results.sorted { $0.composite > $1.composite }
        }
    }

    /// Score one image. Runs off the main actor.
    private static func score(jpeg: Data, index: Int) async -> PhotoScore? {
        guard let ci = CIImage(data: jpeg) else { return nil }

        let landmarksReq = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(ciImage: ci, options: [:])
        try? handler.perform([landmarksReq])

        let faces = landmarksReq.results ?? []
        let faceCount = faces.count

        // Eyes open: VN doesn't directly expose "eyes open" on iOS Vision. We
        // approximate using the eye landmarks' bounding box height: a closed
        // eye collapses to a thin horizontal line. Score is the average
        // openness across all faces, normalized to [0,1].
        let eyesOpen = averageEyeOpenness(faces: faces)

        // Sharpness via variance-of-Laplacian on a 256px downsample.
        let sharpness = sharpness(of: ci)

        // Compose. faceCount is unbounded; cap influence at +5 faces.
        let cappedFaces = min(Double(faceCount), 5.0)
        let composite =
            (cappedFaces * 0.5) +     // weight 0.5 per face up to 5
            (eyesOpen   * 4.0) +      // weight 4 for full open
            (sharpness  * 2.0)        // sharpness already normalized 0..1

        return PhotoScore(
            imageIndex: index,
            faceCount: faceCount,
            eyesOpen: eyesOpen,
            sharpness: sharpness,
            composite: composite
        )
    }

    private static func averageEyeOpenness(faces: [VNFaceObservation]) -> Double {
        guard !faces.isEmpty else { return 0 }
        var total = 0.0
        var counted = 0
        for f in faces {
            guard let lm = f.landmarks else { continue }
            let h1 = aspectRatio(of: lm.leftEye)
            let h2 = aspectRatio(of: lm.rightEye)
            // Combine and normalize: a fully-open eye in VN landmarks has
            // height/width ≈ 0.35; closed ≈ 0.05–0.10.
            let openness = ((h1 ?? 0) + (h2 ?? 0)) / 2
            let normalized = min(1.0, max(0.0, (openness - 0.10) / 0.25))
            total += normalized
            counted += 1
        }
        return counted == 0 ? 0 : total / Double(counted)
    }

    private static func aspectRatio(of region: VNFaceLandmarkRegion2D?) -> Double? {
        guard let region, region.pointCount > 0 else { return nil }
        let pts = region.normalizedPoints
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity
        var minY = CGFloat.infinity, maxY = -CGFloat.infinity
        for p in pts {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let w = max(0.0001, maxX - minX)
        let h = maxY - minY
        return Double(h / w)
    }

    /// Variance-of-Laplacian, normalized to roughly [0, 1] for typical iPhone
    /// photos (anything > 0.4 is sharp, < 0.15 is motion-blurred).
    private static func sharpness(of ci: CIImage) -> Double {
        let target: CGFloat = 256
        let scale = target / ci.extent.width
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Apply a high-pass via Laplacian-like convolution.
        let kernel = CGFloat(-1)
        let weights: [CGFloat] = [
             0, kernel, 0,
            kernel, 4, kernel,
             0, kernel, 0
        ]
        let vec = CIVector(values: weights, count: weights.count)
        guard let conv = CIFilter(name: "CIConvolution3X3", parameters: [
            kCIInputImageKey: scaled,
            "inputWeights": vec,
            "inputBias": NSNumber(value: 0)
        ])?.outputImage else { return 0 }

        // Average the squared output via CIAreaAverage on the magnitude.
        let extent = scaled.extent
        let avgFilter = CIFilter.areaAverage()
        avgFilter.inputImage = conv
        avgFilter.extent = extent
        guard let avgImage = avgFilter.outputImage else { return 0 }

        let ctx = CIContext()
        var pixel = [UInt8](repeating: 0, count: 4)
        ctx.render(avgImage,
                   toBitmap: &pixel,
                   rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8,
                   colorSpace: CGColorSpaceCreateDeviceRGB())

        // Use luma as a proxy for "high-frequency energy". Map 0..40 → 0..1.
        let luma = (Double(pixel[0]) + Double(pixel[1]) + Double(pixel[2])) / 3.0
        return max(0.0, min(1.0, luma / 40.0))
    }
}
