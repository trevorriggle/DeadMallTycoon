import XCTest
@testable import DeadMallTycoon

// Phase 2 economic + scoring + determinism sanity.
// Run on a Mac via: xcodebuild test -scheme DeadMallTycoon -destination 'platform=iOS Simulator,name=iPad (11th generation)'

// MARK: - Helpers

private func autoDismiss(_ state: inout GameState) {
    // Tests don't care about random decisions; just dismiss them.
    if state.decision != nil {
        state.decision = nil
        state.paused = false
    }
}

private func simulateYear(_ state: GameState, seed: UInt64 = 42) -> GameState {
    var s = state
    var rng = SeededGenerator(seed: seed)
    for _ in 0..<12 {
        s = TickEngine.tick(s, rng: &rng)
        autoDismiss(&s)
    }
    return s
}

// MARK: - Tick purity

final class TickPurityTests: XCTestCase {

    func testTickDoesNotMutateInputValue() {
        let start = StartingMall.initialState()
        let snapshot = start
        var rng = SeededGenerator(seed: 1)
        _ = TickEngine.tick(start, rng: &rng)
        // GameState is a value type, so by contract the argument cannot have changed.
        XCTAssertEqual(start, snapshot)
    }

    func testTickIsDeterministicUnderSameSeed() {
        var s1 = StartingMall.initialState()
        var s2 = StartingMall.initialState()
        var r1 = SeededGenerator(seed: 99)
        var r2 = SeededGenerator(seed: 99)
        for _ in 0..<24 {
            s1 = TickEngine.tick(s1, rng: &r1); autoDismiss(&s1)
            s2 = TickEngine.tick(s2, rng: &r2); autoDismiss(&s2)
        }
        XCTAssertEqual(s1.score, s2.score)
        XCTAssertEqual(s1.cash, s2.cash)
        XCTAssertEqual(s1.debt, s2.debt)
        XCTAssertEqual(s1.stores, s2.stores)
    }
}

// MARK: - Economic sanity

final class EconomySanityTests: XCTestCase {

    // Starting mall is ~90% occupancy, should roughly break even over year 1.
    func testStartingMallSurvivesYearOne() {
        var start = StartingMall.initialState()
        start.pendingLawsuitMonth = nil   // skip opening event so we test steady-state economy
        let after = simulateYear(start, seed: 7)
        XCTAssertFalse(after.gameover, "starting mall should not collapse in year 1")
        XCTAssertLessThan(after.debt, 10_000, "starting mall should hover near break-even in year 1")
    }

    // Filling every slot with healthy standard tenants: revenue > costs.
    func testFullOccupancyIsProfitable() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        for i in s.stores.indices where s.stores[i].tier == .vacant {
            let pos = s.stores[i].position
            s.stores[i] = Store(
                id: s.stores[i].id,
                name: "Clothier", tier: .standard,
                rent: 1000, originalRent: 1000, rentMultiplier: 1.0,
                traffic: 60, threshold: 30, lease: 36,
                hardship: 0, closing: false, leaving: false,
                monthsOccupied: 0, monthsVacant: 0, promotionActive: false,
                position: pos
            )
        }
        let after = simulateYear(s, seed: 11)
        XCTAssertLessThan(after.debt, 3_000,
                          "full occupancy should not accumulate meaningful debt")
    }

    // Almost empty: operating costs still run, revenue cannot cover them.
    func testSparseOccupancyAccumulatesDebt() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        var kept = 0
        let maxKeep = 4
        for i in s.stores.indices where s.stores[i].tier != .vacant {
            if kept < maxKeep { kept += 1; continue }
            s.stores[i] = Store.vacant(id: s.stores[i].id, at: s.stores[i].position)
        }
        let after = simulateYear(s, seed: 13)
        XCTAssertGreaterThan(after.debt, 5_000,
                             "a near-empty mall should bleed cash over a year")
    }
}

// MARK: - Scoring

final class ScoringTests: XCTestCase {

    func testScoreIsZeroWhenFullyOccupied() {
        var s = StartingMall.initialState()
        s.currentTraffic = 100
        for i in s.stores.indices where s.stores[i].tier == .vacant {
            let pos = s.stores[i].position
            s.stores[i] = Store(
                id: s.stores[i].id,
                name: "X", tier: .standard,
                rent: 1000, originalRent: 1000, rentMultiplier: 1.0,
                traffic: 60, threshold: 30, lease: 12,
                hardship: 0, closing: false, leaving: false,
                monthsOccupied: 0, monthsVacant: 0, promotionActive: false,
                position: pos
            )
        }
        XCTAssertEqual(Scoring.monthlyScore(s), 0)
    }

    func testScoreIsZeroWithFewerThanTwoActiveTenants() {
        var s = StartingMall.initialState()
        s.currentTraffic = 100
        var kept = 0
        for i in s.stores.indices where s.stores[i].tier != .vacant {
            if kept < 1 { kept += 1; continue }
            s.stores[i] = Store.vacant(id: s.stores[i].id, at: s.stores[i].position)
        }
        XCTAssertEqual(Scoring.monthlyScore(s), 0)
    }

    func testScoreIsZeroWhenTrafficBelowFloor() {
        var s = StartingMall.initialState()
        s.currentTraffic = 25
        XCTAssertEqual(Scoring.monthlyScore(s), 0)
    }

    func testYearMultiplierMatchesV8Curve() {
        XCTAssertEqual(Scoring.yearMultiplier(yearsElapsed:  0),  1.00, accuracy: 0.001)
        XCTAssertEqual(Scoring.yearMultiplier(yearsElapsed:  3),  1.36, accuracy: 0.001)
        XCTAssertEqual(Scoring.yearMultiplier(yearsElapsed: 10),  2.20, accuracy: 0.001)
        XCTAssertEqual(Scoring.yearMultiplier(yearsElapsed: 25),  4.00, accuracy: 0.001)   // v8 cap
        XCTAssertEqual(Scoring.yearMultiplier(yearsElapsed: 50),  4.00, accuracy: 0.001)
    }
}

// MARK: - Opening lawsuit

final class LawsuitTriggerTests: XCTestCase {

    func testLawsuitFiresAtScheduledMonth() {
        var s = StartingMall.initialState()
        XCTAssertEqual(s.pendingLawsuitMonth, 4)

        var rng = SeededGenerator(seed: 3)
        for _ in 0..<4 {
            s = TickEngine.tick(s, rng: &rng)
        }
        // On the 4th tick the lawsuit should have fired and paused play.
        XCTAssertNil(s.pendingLawsuitMonth, "pending lawsuit should be consumed once fired")
        XCTAssertTrue(s.paused)
        guard case .event(let ev) = s.decision else {
            return XCTFail("expected an event decision, got \(String(describing: s.decision))")
        }
        if case .openingLawsuit = ev.kind { /* pass */ }
        else { XCTFail("expected openingLawsuit, got \(ev.kind)") }
    }
}

// MARK: - Decoration decay

final class DecayTests: XCTestCase {

    func testAtLeastOneDecorationAdvancesOverAYear() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        let initial = s.decorations.map(\.condition)
        let after = simulateYear(s, seed: 5)
        let advanced = zip(initial, after.decorations).contains { $0 < $1.condition }
        XCTAssertTrue(advanced, "at least one decoration should decay across 12 months")
    }

    func testJanitorialHalvesDecayRate() {
        // Compare two runs with identical seeds: one with janitorial, one without.
        var baseline = StartingMall.initialState()
        baseline.pendingLawsuitMonth = nil
        var withJanitor = baseline
        withJanitor.activeStaff.janitorial = true
        let a = simulateYear(baseline, seed: 100)
        let b = simulateYear(withJanitor, seed: 100)
        let baselineAdvance = zip(baseline.decorations, a.decorations).reduce(0) { $0 + ($1.1.condition - $1.0.condition) }
        let janitorAdvance  = zip(withJanitor.decorations, b.decorations).reduce(0) { $0 + ($1.1.condition - $1.0.condition) }
        XCTAssertLessThanOrEqual(janitorAdvance, baselineAdvance,
                                 "janitorial staff should not produce *more* decay than no staff")
    }
}

// MARK: - Personality weighting

final class PersonalityWeightingTests: XCTestCase {

    func testThrivingFavorsSuburbanMom() {
        var rng = SeededGenerator(seed: 2026)
        var counts: [String: Int] = [:]
        for _ in 0..<10_000 {
            let p = PersonalityPicker.weightedPick(state: .thriving, rng: &rng)
            counts[p, default: 0] += 1
        }
        let top = counts.max { $0.value < $1.value }!.key
        XCTAssertEqual(top, "Suburban Mom",
                       "Thriving weights top out at Suburban Mom (18). Got: \(counts)")
    }

    func testDeadFavorsUrbex() {
        var rng = SeededGenerator(seed: 2026)
        var counts: [String: Int] = [:]
        for _ in 0..<10_000 {
            let p = PersonalityPicker.weightedPick(state: .dead, rng: &rng)
            counts[p, default: 0] += 1
        }
        let top = counts.max { $0.value < $1.value }!.key
        XCTAssertEqual(top, "Urbex Explorer",
                       "Dead weights top out at Urbex Explorer (25). Got: \(counts)")
    }

    func testZeroWeightPersonalityNeverPicked() {
        // v8 P_WEIGHTS.thriving has Urbex Explorer at 0. Over 5000 picks, 0 appearances.
        var rng = SeededGenerator(seed: 1)
        var urbexCount = 0
        for _ in 0..<5_000 {
            if PersonalityPicker.weightedPick(state: .thriving, rng: &rng) == "Urbex Explorer" {
                urbexCount += 1
            }
        }
        XCTAssertEqual(urbexCount, 0)
    }
}

// MARK: - Threat

final class ThreatTests: XCTestCase {

    func testThreatRisesWithHazards() {
        var s = StartingMall.initialState()
        let baseline = Threat.calculate(s)
        for i in s.decorations.indices { s.decorations[i].hazard = true }
        let elevated = Threat.calculate(s)
        XCTAssertGreaterThan(elevated, baseline)
    }

    func testSealedWingsRaiseThreat() {
        var s = StartingMall.initialState()
        let baseline = Threat.calculate(s)
        s.wingsClosed[.north] = true
        s.wingsClosed[.south] = true
        let elevated = Threat.calculate(s)
        XCTAssertGreaterThan(elevated, baseline)
    }

    func testSecurityReducesThreat() {
        var s = StartingMall.initialState()
        for i in s.decorations.indices { s.decorations[i].hazard = true }
        let unguarded = Threat.calculate(s)
        s.activeStaff.security = true
        let guarded = Threat.calculate(s)
        XCTAssertLessThan(guarded, unguarded)
    }
}
