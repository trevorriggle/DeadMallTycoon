import XCTest
@testable import DeadMallTycoon

// v9 Prompt 5 coverage. Monthly Score = (vacancyScore + memoryScore) ×
// yearMult × lifeMult. Substrates:
//   vacancyScore = totalEmptiness × ScoringTuning.baseVacancyRate (2.0)
//   memoryScore  = Σ artifact.memoryWeight × artifact.decayMultiplier
// Gates preserved from v8: tenants < 2 → 0, traffic < 30 → 0.
// Gate dropped in Prompt 5: totalEmptiness == 0 no longer zeroes the score
// (memory is an independent substrate).
//
// Tuning target: at month 36, vacancyScore:memoryScore should land between
// 65:35 and 75:25. These tests do not assert that ratio — it can only be
// verified in live play on Mac — but they pin the formula shape so any
// future retune is a single-constant change.

final class ScoringFormulaTests: XCTestCase {

    // MARK: - decayMultiplier curve

    func testDecayMultiplierCurveMatchesSpec() {
        let expected: [(Int, Double)] = [
            (0, 1.00),
            (1, 1.25),
            (2, 1.50),
            (3, 1.75),
            (4, 2.00),
        ]
        for (cond, mult) in expected {
            var a = ArtifactFactory.make(
                id: 1, type: .bench, name: "Bench",
                origin: .event(name: "Test"), yearCreated: 1982
            )
            a.condition = cond
            XCTAssertEqual(a.decayMultiplier, mult, accuracy: 0.0001,
                           "condition \(cond) should map to \(mult)×")
        }
    }

    func testDecayMultiplierClampsAboveRuin() {
        // Condition is nominally 0..4 but the field is Int; a stray out-of-range
        // write must not produce an unbounded multiplier.
        var a = ArtifactFactory.make(
            id: 1, type: .bench, name: "Bench",
            origin: .event(name: "Test"), yearCreated: 1982
        )
        a.condition = 99
        XCTAssertEqual(a.decayMultiplier, 2.0, accuracy: 0.0001)
    }

    func testDecayMultiplierClampsBelowPristine() {
        var a = ArtifactFactory.make(
            id: 1, type: .bench, name: "Bench",
            origin: .event(name: "Test"), yearCreated: 1982
        )
        a.condition = -3
        XCTAssertEqual(a.decayMultiplier, 1.0, accuracy: 0.0001)
    }

    // MARK: - vacancyScore

    func testVacancyScoreMatchesTotalEmptinessTimesBaseRate() {
        var s = StartingMall.initialState()
        // Force two slots vacant; sealed wings = 0 on fresh start.
        for i in s.stores.indices where s.stores[i].tier != .vacant {
            s.stores[i].tier = .vacant
            if s.stores.filter({ $0.tier == .vacant }).count >= 2 { break }
        }
        let empties = Scoring.totalEmptiness(s)
        XCTAssertEqual(
            Scoring.vacancyScore(s),
            Double(empties) * Scoring.ScoringTuning.baseVacancyRate,
            accuracy: 0.0001
        )
    }

    func testTotalEmptinessCountsSealedWingsAtFive() {
        var s = StartingMall.initialState()
        let baseline = Scoring.totalEmptiness(s)
        s.wingsClosed[.north] = true
        XCTAssertEqual(Scoring.totalEmptiness(s), baseline + 5)
        s.wingsClosed[.south] = true
        XCTAssertEqual(Scoring.totalEmptiness(s), baseline + 10)
    }

    // MARK: - memoryScore

    func testMemoryScoreZeroOnFreshMall() {
        let s = StartingMall.initialState()
        XCTAssertEqual(Scoring.memoryScore(s), 0.0, accuracy: 0.0001,
                       "no thoughts fired yet → memoryScore must be 0")
    }

    func testMemoryScoreSumsWeightTimesDecay() {
        var s = StartingMall.initialState()
        // Seed two artifacts with known weight and condition.
        // Pick the first two pre-placed artifacts deterministically.
        guard s.artifacts.count >= 2 else {
            return XCTFail("starting mall should seed at least two artifacts")
        }
        s.artifacts[0].memoryWeight = 4.0
        s.artifacts[0].condition    = 0  // decay 1.00×
        s.artifacts[1].memoryWeight = 6.0
        s.artifacts[1].condition    = 4  // decay 2.00×
        // Contribution: 4.0 × 1.00 + 6.0 × 2.00 = 16.0 (plus 0 from remaining).
        XCTAssertEqual(Scoring.memoryScore(s), 16.0, accuracy: 0.0001)
    }

    // MARK: - monthlyScore integration

    func testMonthlyScoreUsesSumSubstrateTimesYearAndLife() {
        var s = StartingMall.initialState()
        s.currentTraffic = 100  // lifeMult = 1.0
        // Year 0 month 0 → yearMult = 1.0.
        // Ensure gates pass: tenants ≥ 2 and traffic ≥ 30. Starting mall
        // satisfies both, but make the substrate values predictable.
        // Clear existing weights so memoryScore is deterministic.
        for i in s.artifacts.indices { s.artifacts[i].memoryWeight = 0 }
        // Seed one artifact weight for memoryScore = 10.0 × 1.0 = 10.0.
        s.artifacts[0].condition = 0
        s.artifacts[0].memoryWeight = 10.0

        let vacancy = Scoring.vacancyScore(s)
        let memory  = Scoring.memoryScore(s)
        let life    = Scoring.lifeMultiplier(s)
        let yearMult = Scoring.yearMultiplier(yearsElapsed: 0)
        let expected = Int((vacancy + memory) * yearMult * life)

        XCTAssertEqual(Scoring.monthlyScore(s), expected)
        XCTAssertEqual(memory, 10.0, accuracy: 0.0001)
    }

    func testMonthlyScoreZeroedWhenTenantsBelowTwo() {
        var s = StartingMall.initialState()
        s.currentTraffic = 100
        for i in s.stores.indices { s.stores[i].tier = .vacant }
        XCTAssertEqual(Scoring.monthlyScore(s), 0,
                       "tenants < 2 gate must still zero the score")
    }

    func testMonthlyScoreZeroedWhenTrafficBelowThirty() {
        var s = StartingMall.initialState()
        s.currentTraffic = 29
        XCTAssertEqual(Scoring.monthlyScore(s), 0,
                       "traffic < 30 gate must still zero the score")
    }

    func testMonthlyScoreNonZeroWhenOnlyMemorySubstrateActive() {
        // Prompt 5 change: the v8 `totalEmptiness == 0 → 0` gate was removed.
        // A mall at full occupancy with accumulated memoryWeight should still
        // score. This is the regression guard for that design call.
        var s = StartingMall.initialState()
        s.currentTraffic = 100
        // Fill every slot so totalEmptiness == 0. Use a nonzero tier.
        for i in s.stores.indices { s.stores[i].tier = .standard }
        // Seed memory weight.
        for i in s.artifacts.indices { s.artifacts[i].memoryWeight = 0 }
        s.artifacts[0].condition    = 4   // 2.0×
        s.artifacts[0].memoryWeight = 50.0

        XCTAssertEqual(Scoring.vacancyScore(s), 0.0, accuracy: 0.0001)
        XCTAssertGreaterThan(Scoring.memoryScore(s), 0.0)
        XCTAssertGreaterThan(Scoring.monthlyScore(s), 0,
                             "memory substrate alone should still score")
    }
}
