import XCTest
import SwiftUI
@testable import AllHandsOnDeck

final class ViewerPreviewLayoutTests: XCTestCase {
    func testLivePreviewUsesFitModeSoControlsDoNotCropTheStream() {
        XCTAssertEqual(ViewerPreviewLayout.livePreviewContentMode, .fit)
    }
}
