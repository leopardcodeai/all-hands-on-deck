import UIKit
import CoreImage.CIFilterBuiltins
import SwiftUI

/// Generates QR images from arbitrary strings (typically session join URLs).
enum QRCodeService {
    private static let context = CIContext()
    private static let filter = CIFilter.qrCodeGenerator()

    /// Returns a UIImage of the given size, or nil if generation fails.
    static func generate(string: String, size: CGFloat = 512) -> UIImage? {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }

        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    static func image(string: String, size: CGFloat = 512) -> Image {
        if let ui = generate(string: string, size: size) {
            return Image(uiImage: ui).interpolation(.none)
        }
        return Image(systemName: "qrcode")
    }
}
