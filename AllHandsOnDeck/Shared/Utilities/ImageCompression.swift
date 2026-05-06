import UIKit
import ImageIO

/// Helpers for downscaling JPEG payloads before pushing them across MCSession.
enum ImageCompression {
    /// Decode an image from data and re-encode at most `maxWidth` wide with
    /// the given JPEG quality. Returns the original data if it fails.
    static func scaledJPEG(data: Data, maxWidth: CGFloat = 1280, quality: CGFloat = 0.7) -> Data {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return data }

        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxWidth
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            return data
        }
        let ui = UIImage(cgImage: cg)
        return ui.jpegData(compressionQuality: quality) ?? data
    }
}
