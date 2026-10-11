import XCTest
@testable import AllHandsOnDeck

final class PirateRankTests: XCTestCase {
    func test_rankThresholdsForAllRanks() {
        XCTAssertEqual(PirateRank.rank(for: 0), .cabinBoy)
        XCTAssertEqual(PirateRank.rank(for: 5), .cabinBoy)
        XCTAssertEqual(PirateRank.rank(for: 10), .deckhand)
        XCTAssertEqual(PirateRank.rank(for: 30), .boatswain)
        XCTAssertEqual(PirateRank.rank(for: 60), .gunner)
        XCTAssertEqual(PirateRank.rank(for: 100), .navigator)
        XCTAssertEqual(PirateRank.rank(for: 150), .quartermaster)
        XCTAssertEqual(PirateRank.rank(for: 200), .firstMate)
        XCTAssertEqual(PirateRank.rank(for: 300), .captain)
        XCTAssertEqual(PirateRank.rank(for: 400), .commodore)
        XCTAssertEqual(PirateRank.rank(for: 550), .admiral)
        XCTAssertEqual(PirateRank.rank(for: 750), .pirateKing)
    }

    func test_rankAboveMaxStaysPirateKing() {
        XCTAssertEqual(PirateRank.rank(for: 1_000_000), .pirateKing)
    }

    func test_rankCount() {
        XCTAssertEqual(PirateRank.allCases.count, 11)
    }

    func test_achievementIDs() {
        XCTAssertNil(PirateRank.cabinBoy.achievementID)
        XCTAssertEqual(PirateRank.deckhand.achievementID, "rank_deckhand")
        XCTAssertEqual(PirateRank.captain.achievementID, "rank_captain")
        XCTAssertEqual(PirateRank.commodore.achievementID, "rank_commodore")
        XCTAssertEqual(PirateRank.admiral.achievementID, "rank_admiral")
        XCTAssertEqual(PirateRank.pirateKing.achievementID, "rank_pirateKing")
    }

    func test_emojiUniqueness() {
        let all = PirateRank.allCases
        let emojiSet = Set(all.map(\.emoji))
        XCTAssertEqual(emojiSet.count, all.count, "Each rank must have a unique emoji")
    }

    func test_allRanksHaveLocalizedTitle() {
        for rank in PirateRank.allCases {
            let title = rank.title
            XCTAssertFalse(title.isEmpty, "Rank \(rank) must have a non-empty title")
            XCTAssertNotEqual(title, rank.emoji, "Rank \(rank) title must not be just its emoji")
        }
    }
}
