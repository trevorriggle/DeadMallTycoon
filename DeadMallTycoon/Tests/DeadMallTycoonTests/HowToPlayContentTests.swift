import XCTest
@testable import DeadMallTycoon

// v9 Prompt 18 — How to Play content coverage.
//
// The reader is scrollable text; tests here pin structural invariants
// rather than copy (copy is authored by Trevor, may change). Invariants:
//   - Exactly 13 sections (the approved count).
//   - Sections are uniquely identified and ordered 1..13.
//   - Every section has a non-empty title and body.
//   - The Scoring section (id 10) must be substantially long enough to
//     hold a formula breakdown — optimization reference, not a tagline.
//     Enforced as a minimum body length; the placeholder already clears
//     this bar, and authored copy will exceed it.
final class HowToPlayContentTests: XCTestCase {

    func testSectionCountIsThirteen() {
        XCTAssertEqual(HowToPlayContent.sections.count, 13)
    }

    func testSectionIdsAreUniqueAndOrdered() {
        let ids = HowToPlayContent.sections.map { $0.id }
        XCTAssertEqual(ids, Array(1...13),
            "Section ids must be 1..13 in order (renumbering is a contract change)")
    }

    func testEverySectionHasTitleAndBody() {
        for section in HowToPlayContent.sections {
            XCTAssertFalse(section.title.isEmpty,
                "Section \(section.id) missing title")
            XCTAssertFalse(section.body.isEmpty,
                "Section \(section.id) missing body")
        }
    }

    func testScoringSectionHasRoomForFullFormula() {
        guard let scoring = HowToPlayContent.sections.first(where: { $0.id == 10 })
        else {
            XCTFail("Section id 10 (Scoring in detail) not found")
            return
        }
        XCTAssertTrue(scoring.title.lowercased().contains("scoring"),
            "Section 10 is the Scoring reference — title must reflect that")
        // The authored reference enumerates: monthlyScore formula,
        // emptyScore, memoryScore, memoryContribution, actionBurst,
        // yearCurve, lifeMultiplier, stateMemoryMultiplier table,
        // worked examples. The placeholder body already runs >400
        // characters; authored copy will exceed that. 400 is a
        // conservative floor that catches a one-line regression.
        XCTAssertGreaterThan(scoring.body.count, 400,
            "Scoring section body is too short to hold the full formula reference")
    }

    func testCreditsSectionIsLast() {
        guard let last = HowToPlayContent.sections.last else {
            XCTFail("Empty sections list")
            return
        }
        XCTAssertEqual(last.id, 13)
        XCTAssertTrue(last.title.lowercased().contains("credits")
                   || last.title.lowercased().contains("acknowledg"),
            "Final section is the credits + acknowledgments placeholder")
    }
}
