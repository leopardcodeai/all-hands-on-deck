import XCTest
import UIKit
@testable import AllHandsOnDeck

final class ImageCompressionTests: XCTestCase {
    func test_scaledJPEG_returnsSmallerData_forLargeImage() throws {
        // Procedurally-generated 4000×4000 image — guaranteed to compress big.
        let size = CGSize(width: 4000, height: 4000)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            for x in stride(from: 0, to: Int(size.width), by: 80) {
                for y in stride(from: 0, to: Int(size.height), by: 80) {
                    let color = UIColor(hue: CGFloat((x + y) % 360) / 360,
                                        saturation: 0.7, brightness: 0.85, alpha: 1)
                    color.setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 80, height: 80))
                }
            }
        }
        let original = try XCTUnwrap(img.jpegData(compressionQuality: 0.95))
        XCTAssertGreaterThan(original.count, 200_000, "Source should be substantial")

        let scaled = ImageCompression.scaledJPEG(data: original, maxWidth: 1280, quality: 0.7)
        XCTAssertLessThan(scaled.count, original.count)

        let decoded = try XCTUnwrap(UIImage(data: scaled))
        XCTAssertLessThanOrEqual(decoded.size.width, 1280 + 1)
        XCTAssertLessThanOrEqual(decoded.size.height, 1280 + 1)
    }

    func test_scaledJPEG_returnsOriginalOnGarbage() {
        let bogus = Data([0x00, 0x01, 0x02])
        let result = ImageCompression.scaledJPEG(data: bogus, maxWidth: 1280, quality: 0.7)
        XCTAssertEqual(result, bogus)
    }
}
