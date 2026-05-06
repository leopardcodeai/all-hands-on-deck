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
}
