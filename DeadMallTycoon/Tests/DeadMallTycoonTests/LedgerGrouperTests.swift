import XCTest
@testable import DeadMallTycoon

// v9 Prompt 9 Phase B — pure-logic coverage for:
//   - LedgerGrouper.groupByYear  (renders into year blocks)
//   - LedgerEntry.year / .month  (accessors used by the grouper and by
//                                  future Phase C focus helpers)
//
// UI-level coverage (ManageDrawer .history tab, GameOverView body) is
// not unit-testable without a SwiftUI test harness; those land on
// manual playtesting + a visual check.

// MARK: - Helpers

private func closure(year: Int, month: Int = 0,
                     name: String = "X") -> LedgerEntry {
    .closure(ClosureEvent(
        id: UUID(), tenantName: name, tenantTier: .standard,
        yearsOpen: 1, slotId: 1, year: year, month: month))
}

private func created(year: Int, month: Int = 0) -> LedgerEntry {
    .artifactCreated(
        artifactId: 1, name: "Fountain", type: .fountain,
        origin: .playerAction("placed"), year: year, month: month)
}

// MARK: - Grouper

final class LedgerGrouperTests: XCTestCase {

    func testEmptyInputProducesEmptyOutput() {
        XCTAssertEqual(LedgerGrouper.groupByYear([]), [])
    }

    func testSingleEntryProducesOneGroup() {
        let e = closure(year: 1985)
        let groups = LedgerGrouper.groupByYear([e])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].year, 1985)
        XCTAssertEqual(groups[0].entries, [e])
    }

    func testMultipleEntriesSameYearCollapseIntoOneGroup() {
        let e1 = closure(year: 1985, month: 2)
        let e2 = created(year: 1985, month: 5)
        let e3 = closure(year: 1985, month: 11)
        let groups = LedgerGrouper.groupByYear([e1, e2, e3])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].year, 1985)
        XCTAssertEqual(groups[0].entries, [e1, e2, e3],
                       "within-year order is preserved verbatim")
    }

    func testEntriesAcrossMultipleYearsProduceAdjacentGroupsInOrder() {
        let a = closure(year: 1985)
        let b = closure(year: 1985)
        let c = closure(year: 1986)
        let d = closure(year: 1988)
        let e = closure(year: 1988)
        let groups = LedgerGrouper.groupByYear([a, b, c, d, e])
        XCTAssertEqual(groups.map(\.year), [1985, 1986, 1988])
        XCTAssertEqual(groups[0].entries, [a, b])
        XCTAssertEqual(groups[1].entries, [c])
        XCTAssertEqual(groups[2].entries, [d, e])
    }

    // Defensive: if entries aren't in chronological order (shouldn't
    // happen in production — ledger is append-only in tick order), the
    // grouper preserves source order by starting a new group on every
    // year change. The test pins that contract so the grouper doesn't
    // silently re-sort.
    func testOutOfOrderInputStartsNewGroupOnYearChange() {
        let entries = [
            closure(year: 1985),
            closure(year: 1987),
            closure(year: 1985),   // year goes backwards
            closure(year: 1986),
        ]
        let groups = LedgerGrouper.groupByYear(entries)
        XCTAssertEqual(groups.map(\.year), [1985, 1987, 1985, 1986],
                       "years repeat because source order is preserved, not re-sorted")
        XCTAssertEqual(groups.map { $0.entries.count }, [1, 1, 1, 1])
    }
}

// MARK: - year / month accessors

final class LedgerEntryTimestampAccessorTests: XCTestCase {

    // One constructed sample per case. Each assertion pins the exact
    // fields the accessor should pull, so adding a new case without
    // extending the accessor switches will fail here (via the switch's
    // exhaustive-init guarantee).
    func testYearAndMonthReturnTheEmbeddedTimestamp() {
        let samples: [(LedgerEntry, Int, Int)] = [
            (closure(year: 1985, month: 3), 1985, 3),
            (.offerDestruction(tenantName: "A", newTenantName: "B",
                                yearsBoarded: 1, memoryWeight: 0,
                                thoughtReferenceCount: 0,
                                year: 1986, month: 4), 1986, 4),
            (.artifactSealed(tenantName: "A", sourceType: .boardedStorefront,
                              memoryWeight: 0, thoughtReferenceCount: 0,
                              year: 1987, month: 5), 1987, 5),
            (.displayConversion(tenantName: "A", content: .historicalPlaque,
                                 memoryWeight: 0, thoughtReferenceCount: 0,
                                 year: 1988, month: 6), 1988, 6),
            (.displayReverted(tenantName: "A", content: .historicalPlaque,
                               memoryWeight: 0, thoughtReferenceCount: 0,
                               year: 1989, month: 7), 1989, 7),
            (created(year: 1990, month: 8), 1990, 8),
            (.decayTransition(artifactId: 1, name: "F", type: .fountain,
                               fromCondition: 0, toCondition: 1,
                               year: 1991, month: 9), 1991, 9),
            (.artifactDestroyed(artifactId: 1, name: "F", type: .fountain,
                                 reason: "flood", year: 1992, month: 10), 1992, 10),
            (.envTransition(from: .thriving, to: .fading,
                             year: 1993, month: 11), 1993, 11),
            (.anchorDeparture(tenantName: "H", wing: .north,
                               trafficDelta: -300,
                               coincidentClosureNames: [],
                               yearsOpen: 10, slotId: 1,
                               year: 1994, month: 0), 1994, 0),
            (.attentionMilestone(artifactId: 1, name: "Kugel Ball",
                                  type: .kugelBall, threshold: 100,
                                  year: 1995, month: 1), 1995, 1),
        ]
        for (entry, expectedYear, expectedMonth) in samples {
            XCTAssertEqual(entry.year, expectedYear)
            XCTAssertEqual(entry.month, expectedMonth)
        }
    }
}
