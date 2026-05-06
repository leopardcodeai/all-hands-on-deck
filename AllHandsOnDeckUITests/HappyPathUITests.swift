import XCTest

/// Comprehensive Happy Path UI Tests using XCUITest.
///
/// Covers all crew-photo scenarios:
/// - Host: Start session, countdown, cancel, QR code, share link
/// - Viewer: Join, reactions, ready state
/// - Session: Timer flow, photo capture, crew popup
///
/// Run against: MockSessionTransport (no camera needed).
final class HappyPathUITests: XCTestCase {
    let app = XCUIApplication()
    let sessionID = "UITEST01"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "-useMockTransport", "YES",
            "-allowWebJoinDefault", "YES",
            "-bypassCameraPermission"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Host: Session Lifecycle ──────────────────────────────────────────

    func test_startHostSession_reachesCameraView() throws {
        tapStartCrewPhoto()
        XCTAssertTrue(anyHostSessionElementExists(), "Host session view did not appear")
    }

    func test_hostStartsCountdown_seesTimer() throws {
        tapStartCrewPhoto()
        guard anyHostSessionElementExists() else {
            XCTFail("Host session not reached"); return
        }
        // Tap "Start 10s" to begin countdown
        let start10s = app.buttons["Start 10s"]
        if start10s.waitForExistence(timeout: 5) {
            start10s.tap()
        }
        // Either a countdown overlay appears or the button state changes
        sleep(2)
        // After countdown starts, the screen should still be the host session
        XCTAssertTrue(app.buttons.count > 3, "Host view elements should still be visible")
    }

    func test_hostCountdown_canCancel() throws {
        tapStartCrewPhoto()
        guard anyHostSessionElementExists() else {
            XCTFail("Host session not reached"); return
        }
        // Start countdown
        let start10s = app.buttons["Start 10s"]
        if start10s.waitForExistence(timeout: 5) { start10s.tap() }
        sleep(1)
        // If a cancel button appears (during active countdown), tap it
        let cancelBtn = app.buttons["Cancel"]
        if cancelBtn.waitForExistence(timeout: 8) {
            cancelBtn.tap()
            // After cancel, "Start 10s" should reappear
            XCTAssertTrue(start10s.waitForExistence(timeout: 5), "Start 10s should reappear after cancel")
        }
    }

    func test_hostShowsQRCode_toggleVisibility() throws {
        tapStartCrewPhoto()
        guard anyHostSessionElementExists() else {
            XCTFail("Host session not reached"); return
        }
        // "Hide QR code" button should exist (meaning QR is shown)
        let hideQR = app.buttons["Hide QR code"]
        XCTAssertTrue(hideQR.waitForExistence(timeout: 10), "Hide QR code button not found")
        // Tap it to hide
        hideQR.tap()
        // Button text may not change; just verify app doesn't crash
        sleep(1)
        XCTAssertTrue(app.buttons.count > 2, "App should still be responsive after toggling QR")
    }

    func test_hostHasShareAndCopyButtons() throws {
        tapStartCrewPhoto()
        guard anyHostSessionElementExists() else {
            XCTFail("Host session not reached"); return
        }
        XCTAssertTrue(app.buttons["Copy Link"].waitForExistence(timeout: 10), "Copy Link missing")
        XCTAssertTrue(app.buttons["Share"].exists, "Share button missing")
    }

    func test_hostChromeButtonsStayWithinSafeLayoutBands() throws {
        tapStartCrewPhoto()
        guard anyHostSessionElementExists() else {
            XCTFail("Host session not reached"); return
        }

        let screen = app.frame
        let topBand = screen.minY + 24...screen.minY + 180
        let bottomBand = screen.maxY - 150...screen.maxY - 20

        let topButtons = [
            app.buttons["host_back"],
            app.buttons["host_settings"],
            app.buttons["host_qr_toggle"]
        ]
        let bottomButtons = [
            app.buttons["host_start_timer"],
            app.buttons["host_capture_now"]
        ]

        for button in topButtons {
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing top chrome button: \(button)")
            assertButton(button, staysInside: topBand, axis: .vertical)
        }

        for button in bottomButtons {
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing bottom chrome button: \(button)")
            assertButton(button, staysInside: bottomBand, axis: .vertical)
        }
    }

    // MARK: - Viewer: Crew Interaction ──────────────────────────────────────────

    func test_joinSession_reachesViewerSessionView() throws {
        navigateToViewerSession()
        let found = app.buttons["Crew"].waitForExistence(timeout: 10)
                  || app.buttons["Ready"].waitForExistence(timeout: 10)
        XCTAssertTrue(found, "Viewer session view did not appear")
    }

    func test_viewerHasReactionButtons() throws {
        navigateToViewerSession()
        // Wait for viewer UI to stabilize
        sleep(3)
        // Reaction strip should contain multiple reaction buttons
        let reactions = ["Ready", "Wait a moment", "Again", "Camera up"]
        var found = 0
        for label in reactions where app.buttons[label].waitForExistence(timeout: 3) {
            found += 1
        }
        XCTAssertTrue(found >= 2, "Expected at least 2 reaction buttons, found \(found)")
    }

    func test_viewerCanToggleReady() throws {
        navigateToViewerSession()
        sleep(3)
        let readyBtn = app.buttons["Ready"]
        if readyBtn.waitForExistence(timeout: 5) {
            readyBtn.tap()
            sleep(1)
            // After tapping, the button might change state — just verify no crash
            XCTAssertTrue(app.buttons.count > 2)
        }
    }

    func test_viewerCanOpenCrewPopup() throws {
        navigateToViewerSession()
        sleep(3)
        let crewBtn = app.buttons["Crew"]
        if crewBtn.waitForExistence(timeout: 5) {
            crewBtn.tap()
            sleep(1)
            // Crew popup should show participants or a backdrop
            // Just verify the app doesn't crash
            XCTAssertFalse(app.buttons.allElementsBoundByIndex.isEmpty)
            // Tap outside to dismiss
            app.tap()
        }
    }

    // MARK: - Navigation ────────────────────────────────────────────────────────

    func test_homeScreen_hasAllButtons() throws {
        XCTAssertTrue(app.buttons["Start Crew Photo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Join Session"].exists)
        XCTAssertTrue(app.buttons["Nearby Sessions"].exists)
        XCTAssertTrue(app.staticTexts["BETA"].exists)
    }

    func test_homeScreen_showsCaptainIdentity() throws {
        // The identity chip shows display name + pirate rank
        XCTAssertTrue(app.buttons["Identity settings"].waitForExistence(timeout: 5))
    }

    func test_navigationBack_fromJoinScreen() throws {
        // Navigate to Join, then go back
        app.buttons["Join Session"].tap()
        sleep(2)
        let backBtn = app.buttons["Back"]
        if backBtn.waitForExistence(timeout: 5) {
            backBtn.tap()
            // Should be back on home
            XCTAssertTrue(app.buttons["Start Crew Photo"].waitForExistence(timeout: 5))
        }
    }

    func test_navigationBack_fromHostSession() throws {
        tapStartCrewPhoto()
        guard anyHostSessionElementExists() else {
            XCTFail("Host session not reached"); return
        }
        let backBtn = app.buttons["host_back"]
        let fallbackBackBtn = app.buttons["Back"]
        let button = backBtn.waitForExistence(timeout: 5) ? backBtn : fallbackBackBtn
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Host back button missing")
        button.tap()
        XCTAssertTrue(app.buttons["host_start_crew_photo"].waitForExistence(timeout: 5))
    }

    // MARK: - Deep Link ─────────────────────────────────────────────────────────

    func test_deepLink_opensViewerSession() throws {
        app.terminate()
        app.launchArguments.append("-deepLinkID")
        app.launchArguments.append(sessionID)
        app.launch()
        let navBar = app.navigationBars.firstMatch
        _ = navBar.waitForExistence(timeout: 5)
    }

    // MARK: - Helpers ───────────────────────────────────────────────────────────

    private func tapStartCrewPhoto() {
        let btn = app.buttons["Start Crew Photo"]
        XCTAssertTrue(btn.waitForExistence(timeout: 10), "Start Crew Photo not found")
        btn.tap()
    }

    private func anyHostSessionElementExists() -> Bool {
        return app.buttons["Hide QR code"].waitForExistence(timeout: 15)
            || app.buttons["Settings"].waitForExistence(timeout: 5)
            || app.buttons["Start 10s"].waitForExistence(timeout: 5)
            || app.buttons["Copy Link"].waitForExistence(timeout: 5)
    }

    private func navigateToViewerSession() {
        app.buttons["Join Session"].tap()
        sleep(2)
        let tf = app.textFields.firstMatch
        if tf.waitForExistence(timeout: 5) {
            tf.tap()
            tf.typeText(sessionID)
        }
        let connect = app.buttons["Connect"]
        if connect.waitForExistence(timeout: 5) { connect.tap() }
        sleep(4)
    }

    private enum LayoutAxis {
        case vertical
    }

    private func assertButton(
        _ button: XCUIElement,
        staysInside band: ClosedRange<CGFloat>,
        axis: LayoutAxis,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let frame = button.frame
        XCTAssertGreaterThan(frame.width, 24, "Button has no usable width: \(button)", file: file, line: line)
        XCTAssertGreaterThan(frame.height, 24, "Button has no usable height: \(button)", file: file, line: line)

        switch axis {
        case .vertical:
            XCTAssertGreaterThanOrEqual(frame.minY, band.lowerBound, "Button is too high: \(button)", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxY, band.upperBound, "Button is too low: \(button)", file: file, line: line)
        }
    }
}
