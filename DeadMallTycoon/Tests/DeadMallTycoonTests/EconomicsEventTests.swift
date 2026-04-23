import XCTest
@testable import DeadMallTycoon

// v9 Prompt 15 Phase 1 coverage. Per-tick economics trace: rent per
// store, hazard fine per artifact, aggregate operating cost. Animation
// behavior (floating labels, HUD count-up) isn't unit-testable; those
// land on manual playtest.

// MARK: - Economy per-source helpers

final class EconomyPerSourceTests: XCTestCase {

    func testRentByStoreIncludesOnlyPayingNonClosedTenants() {
        var s = StartingMall.initialState()
        let items = Economy.rentByStore(s)
        // Starting seed: 16 occupied + 2 vacant + 0 sealed wings. All
        // non-vacant stores pay rent (vacants have rent=0, filtered).
        let occupied = s.stores.filter { $0.tier != .vacant }.count
        XCTAssertEqual(items.count, occupied)
        // Sum equals Economy.rent aggregate.
        XCTAssertEqual(items.reduce(0) { $0 + $1.amount },
                       Economy.rent(s))

        // Seal the north wing — rent from that wing's stores drops out.
        s.wingsClosed[.north] = true
        let afterSeal = Economy.rentByStore(s)
        XCTAssertLessThan(afterSeal.count, items.count,
                          "wing-sealed stores no longer contribute rent events")
        XCTAssertEqual(afterSeal.reduce(0) { $0 + $1.amount },
                       Economy.rent(s))
    }

    func testRentByStoreAppliesSaleDiscount() {
        var s = StartingMall.initialState()
        let before = Economy.rentByStore(s)
        // Activate the sale promo directly.
        let sale = Promotions.all.first(where: { $0.effect == .sale })!
        s.activePromos.append(ActivePromotion(from: sale, remaining: 2))

        let after = Economy.rentByStore(s)
        XCTAssertEqual(after.count, before.count)
        // Each non-zero rent gets multiplied by 0.8 and rounded.
        for (b, a) in zip(before, after) {
            let expected = Int((Double(b.amount) * 0.8).rounded())
            XCTAssertEqual(a.amount, expected,
                           "sale discount applied per-store")
        }
    }

    func testHazardFinesByArtifactFiltersNonHazardous() {
        var s = StartingMall.initialState()
        XCTAssertTrue(Economy.hazardFinesByArtifact(s).isEmpty,
                      "starting seed has no hazards")

        // Flag one artifact as hazard at condition 3.
        s.artifacts[0].hazard = true
        s.artifacts[0].condition = 3
        let items = Economy.hazardFinesByArtifact(s)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].artifactId, s.artifacts[0].id)
        XCTAssertEqual(items[0].amount, 500 + 3 * 200,
                       "fine formula: 500 + condition × 200")
    }

    func testHazardFinesAggregateMatchesSum() {
        var s = StartingMall.initialState()
        s.artifacts[0].hazard = true
        s.artifacts[0].condition = 2
        s.artifacts[1].hazard = true
        s.artifacts[1].condition = 4
        let items = Economy.hazardFinesByArtifact(s)
        XCTAssertEqual(items.reduce(0) { $0 + $1.amount },
                       Economy.hazardFines(s))
    }
}

// MARK: - TickEngine emission

final class EconomicsEventEmissionTests: XCTestCase {

    func testEventsPopulatedAfterTick() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        XCTAssertTrue(s.lastTickEconomicsEvents.isEmpty)
        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertFalse(s.lastTickEconomicsEvents.isEmpty,
                       "tick populates the events queue")
    }

    func testEventsReplaceRatherThanAccumulate() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        let afterFirst = s.lastTickEconomicsEvents.count
        s = TickEngine.tick(s, rng: &rng)
        let afterSecond = s.lastTickEconomicsEvents.count
        XCTAssertEqual(afterFirst, afterSecond,
                       "events are replaced per tick, not appended")
    }

    func testRentEventEmittedPerPayingStore() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)

        let rentEvents = s.lastTickEconomicsEvents.compactMap { event -> Int? in
            if case .rentCollected(let storeId, _) = event { return storeId }
            return nil
        }
        // Some stores may close/vacate during the tick — filter to the
        // stores that are currently occupied (approximates the post-tick
        // snapshot that generated the events).
        let occupiedIds = Set(s.stores
            .filter { $0.tier != .vacant && !Mall.isWingClosed($0.wing, in: s) }
            .map { $0.id })
        XCTAssertFalse(rentEvents.isEmpty,
                       "at least one rent event fired for a healthy starting mall")
        for storeId in rentEvents {
            XCTAssertTrue(occupiedIds.contains(storeId),
                          "rent event storeId \(storeId) should reference an occupied store")
        }
    }

    func testOperatingCostEventEmittedWhenNonZero() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)

        let opsEvents = s.lastTickEconomicsEvents.filter { event in
            if case .operatingCost = event { return true }
            return false
        }
        // Should be exactly one (aggregate), since operating + staff +
        // promo costs almost always sum to > 0 on a live mall.
        XCTAssertEqual(opsEvents.count, 1,
                       "operating-cost event is aggregate: exactly one per tick")
    }

    func testHazardFineEventEmittedForHazardousArtifact() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s.artifacts[0].hazard = true
        s.artifacts[0].condition = 2
        let hazardId = s.artifacts[0].id

        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)

        let fineEvents = s.lastTickEconomicsEvents.compactMap { event -> (Int, Int)? in
            if case .hazardFine(let artifactId, let amount) = event {
                return (artifactId, amount)
            }
            return nil
        }
        XCTAssertEqual(fineEvents.count, 1)
        XCTAssertEqual(fineEvents[0].0, hazardId)
        XCTAssertEqual(fineEvents[0].1, 500 + 2 * 200)
    }
}
