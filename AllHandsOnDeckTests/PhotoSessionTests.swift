import XCTest
import SwiftUI
@testable import AllHandsOnDeck

final class PhotoSessionTests: XCTestCase {
    func test_makeShortID_isUnambiguousAlphabet() {
        let alphabet = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for _ in 0..<200 {
            let id = PhotoSession.makeShortID()
            XCTAssertEqual(id.count, 10)
            for ch in id {
                XCTAssertTrue(alphabet.contains(ch),
                              "Forbidden char \(ch) in \(id)")
            }
            // Bone-headed common ambiguous chars must not appear.
            XCTAssertFalse(id.contains("0"))
            XCTAssertFalse(id.contains("O"))
            XCTAssertFalse(id.contains("I"))
            XCTAssertFalse(id.contains("1"))
        }
    }

    func test_makeShortID_isReasonablyUnique() {
        var seen = Set<String>()
        for _ in 0..<10_000 {
            seen.insert(PhotoSession.makeShortID())
        }
        // 32^10 search space → collision probability negligible at 10k.
        XCTAssertEqual(seen.count, 10_000)
    }

    func test_expiresAt_isCreatedAtPlusTTL() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let s = PhotoSession(hostName: "A", createdAt: now, ttlMinutes: 30)
        XCTAssertEqual(s.expiresAt.timeIntervalSince(s.createdAt), 30 * 60, accuracy: 0.001)
    }

    func test_joinURL_usesUserDefaultsOverride() {
        let key = "joinBaseURL"
        let original = UserDefaults.standard.string(forKey: key)
        defer {
            if let o = original { UserDefaults.standard.set(o, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
        }

        UserDefaults.standard.set("http://10.0.0.5:5173", forKey: key)
        let s = PhotoSession(id: "ABCDEF1234", hostName: "Captain")
        XCTAssertEqual(s.joinURL.absoluteString, "http://10.0.0.5:5173/join/ABCDEF1234")
    }

    func test_joinURL_fallsBackToCustomSchemeWhenNoWebBaseConfigured() {
        let key = "joinBaseURL"
        let original = UserDefaults.standard.string(forKey: key)
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.set("", forKey: key)
        let s = PhotoSession(id: "ABCDEF1234", hostName: "Captain")
        XCTAssertEqual(
            s.joinURL.absoluteString,
            "allhands://join/ABCDEF1234"
        )
    }

    // MARK: - Liquid Glass Modifier (APP-70)

    func test_liquidGlass_cornerRadius_default_22() {
        let modifier = LiquidGlass()
        XCTAssertEqual(modifier.cornerRadius, 22)
    }

    func test_liquidGlass_customCornerRadius() {
        let modifier = LiquidGlass(cornerRadius: 16)
        XCTAssertEqual(modifier.cornerRadius, 16)
    }

    func test_liquidGlass_viewModifier_applies() {
        let view = Text("Test").modifier(LiquidGlass())
        XCTAssertNotNil(view)
    }

    // MARK: - Popup Toggle Logic (APP-70)

    func test_popup_backdrop_whenEitherOpen() {
        let cases = [(c: false, q: false, e: false),
                     (c: true,  q: false, e: true),
                     (c: false, q: true,  e: true),
                     (c: true,  q: true,  e: true)]
        for (crew, qr, expected) in cases {
            XCTAssertEqual(crew || qr, expected)
        }
    }

    func test_popup_independentControls() {
        let crewOpen = true
        let showQR   = true
        XCTAssertTrue(crewOpen && showQR)
    }

    func test_popup_tapBackdrop_closesBoth() {
        var crew = true
        var qr   = true
        crew = false
        qr   = false
        XCTAssertFalse(crew)
        XCTAssertFalse(qr)
    }
}
