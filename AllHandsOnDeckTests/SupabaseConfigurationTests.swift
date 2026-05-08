import XCTest
@testable import AllHandsOnDeck

final class SupabaseConfigurationTests: XCTestCase {
    func test_supabaseConfigRejectsEmptyAndTemplateValues() {
        XCTAssertFalse(SupabaseSessionTransport.hasUsableConfig(url: "", anonKey: ""))
        XCTAssertFalse(SupabaseSessionTransport.hasUsableConfig(url: "https://YOUR-PROJECT-REF.supabase.co", anonKey: "TODO"))
        XCTAssertFalse(SupabaseSessionTransport.hasUsableConfig(url: "https://edylzgxrknbqjdgtrgic.supabase.co", anonKey: "TODO"))
    }

    func test_supabaseConfigAcceptsProjectURLAndAnonJWT() {
        let anon = [
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
            "eyJyb2xlIjoiYW5vbiJ9",
            "signature"
        ].joined(separator: ".")

        XCTAssertTrue(SupabaseSessionTransport.hasUsableConfig(
            url: "https://edylzgxrknbqjdgtrgic.supabase.co",
            anonKey: anon
        ))
    }

    @MainActor
    func test_supabaseConfigResolvesFromInfoPlist() {
        XCTAssertTrue(SupabaseSessionTransport.isConfigured,
                      "isConfigured must be true — the xcconfig chain (Debug → Secrets) "
                      + "must provide SUPABASE_URL and SUPABASE_ANON_KEY to Info.plist")
    }

    func test_mediaEventsAreNotSentToSupabaseInDefaultMode() {
        let mediaEvents: [SessionEvent] = [
            .previewFrame(jpeg: Data([0xFF, 0xD8, 0xFF]), capturedAt: Date()),
            .finalPhotoAvailable(photoID: "test", jpeg: Data([0xFF, 0xD8, 0xFF]))
        ]
        for event in mediaEvents {
            XCTAssertTrue(event.isMediaEvent,
                          "\(event) must be classified as media event and excluded from Supabase")
        }
    }

    func test_controlEventsAreNotClassifiedAsMedia() {
        let controlEvents: [SessionEvent] = [
            .sessionMetadata(PhotoSession(hostName: "test")),
            .participantJoined(Participant(id: "1", displayName: "p", role: .viewer, connectionType: .web)),
            .participantLeft(participantID: "1"),
            .participantReadyChanged(participantID: "1", isReady: true),
            .countdownStarted(photoAt: Date(), duration: 10, startedBy: "host"),
            .countdownCancelled(by: "host"),
            .captureRequested(by: "viewer"),
            .captureNowRequested(by: "viewer"),
            .captureApproved(approvedBy: "host"),
            .captureDenied(deniedBy: "host"),
            .photoCaptured(at: Date()),
            .reactionSent(by: "viewer", reaction: "👍"),
            .sessionEnded
        ]
        for event in controlEvents {
            XCTAssertFalse(event.isMediaEvent,
                           "\(event) must NOT be classified as media event — control events must reach Supabase")
        }
    }
}
