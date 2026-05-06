import Foundation
import UIKit

/// A captured group photo result.
struct CapturedPhoto: Identifiable, Sendable {
    let id: String
    let capturedAt: Date
    let imageData: Data

    init(id: String = UUID().uuidString, capturedAt: Date = Date(), imageData: Data) {
        self.id = id
        self.capturedAt = capturedAt
        self.imageData = imageData
    }

    var uiImage: UIImage? { UIImage(data: imageData) }
}
