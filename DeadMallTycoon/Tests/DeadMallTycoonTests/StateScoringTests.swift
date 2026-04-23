import XCTest
@testable import DeadMallTycoon

// v9 Prompt 13 coverage. Four interlocking mechanisms:
//   - stateMemoryMultiplier shifts memory contribution per env state
//   - Gate split: vacancy strict, memory relaxed to activeTenants >= 1
//   - actionBurst: immediate score events on curation, scaled by state
//   - Memory weight decay: artifacts uncontacted 6+ months lose 5%/tick

// MARK: - Helpers

private func freshState() -> GameState {
    var s = StartingMall.initialState()
    s.pendingLawsuitMonth = nil
    s.currentTraffic = 100    // lifeMult = 1.0
    return s
}

// Force env state by mutating occupancy (Mall.state reads occupancy ratio).
private func setOccupancy(_ s: inout GameState, ratio: Double) {
    let total = s.stores.count
    let targetOccupied = Int(Double(total) * ratio)
    // Reset all to standard, then vacate enough to hit target.
    for i in s.stores.indices {
        s.stores[i].tier = .standard
        s.stores[i].name = "Tenant\(i)"
    }
    var toVacate = total - targetOccupied
    var i = s.stores.indices.last ?? 0
    while toVacate > 0, i >= 0 {
        s.stores[i].tier = .vacant
        s.stores[i].name = ""
        toVacate -= 1
        i -= 1
    }
}

// MARK: - stateMemoryMultiplier table

final class StateMemoryMultiplierTests: XCTestCase {

    func testMultiplierValuesMatchSpec() {
        let table = Scoring.ScoringTuning.stateMemoryMultiplier
        XCTAssertEqual(table[.thriving],   1.0)
        XCTAssertEqual(table[.fading],     1.0)
        XCTAssertEqual(table[.struggling], 1.2)
        XCTAssertEqual(table[.dying],      1.5)
        XCTAssertEqual(table[.dead],       1.8)
        XCTAssertEqual(table[.ghostMall],  2.0)
    }

    // Memory contribution at thriving should be unchanged from Prompt 5
    // (multiplier 1.0 = identity).
    func testThrivingBehavesLikePromptFive() {
        var s = freshState()
        for i in s.artifacts.indices { s.artifacts[i].memoryWeight = 0 }
        s.artifacts[0].memoryWeight = 10.0
        s.artifacts[0].condition = 0   // decay 1.0×

        // Memory substrate raw = 10. Thriving multiplier 1.0.
        // Expected memory contribution = 10 × 1.0 × yearMult(0) × life(1.0)
        //                              = 10 × 1.0 × 1.0 × 1.0 = 10.
        // Plus vacancy (starting has 2 vacants → vacancyScore = 4.0).
        // Total = 14.
        XCTAssertEqual(EnvironmentState.from(s), .thriving)
        XCTAssertEqual(Scoring.monthlyScore(s), 14)
    }

    // At higher decline, memory contribution scales up.
    func testDeclineInflatesMemoryContribution() {
        // Build a state at .dying — need occupancy ratio 20-40%.
        var s = freshState()
        setOccupancy(&s, ratio: 0.30)
        for i in s.artifacts.indices { s.artifacts[i].memoryWeight = 0 }
        s.artifacts[0].memoryWeight = 10.0
        s.artifacts[0].condition = 0

        XCTAssertEqual(EnvironmentState.from(s), .dying)
        // memory × stateMult(1.5) × yearMult(1) × life(1) = 10 × 1.5 = 15
        // Vacancy contribution: activeTenants ≈ 5, vacants = 13. vacancyScore = 26.
        // vacancy × yearMult × life = 26.
        // Total = 26 + 15 = 41.
        XCTAssertEqual(Scoring.monthlyScore(s), 41)
    }
}

// MARK: - Gate split

final class ScoringGateSplitTests: XCTestCase {

    func testZeroTenantsFullyZeroes() {
        var s = freshState()
        for i in s.stores.indices { s.stores[i].tier = .vacant }
        s.artifacts[0].memoryWeight = 99   // lots of memory
        XCTAssertEqual(Scoring.monthlyScore(s), 0,
                       "activeTenants < 1 → full zero regardless of memory")
    }

    func testOneTenantHoldoutPreservesMemoryScoring() {
        // The ENDGAME fantasy: one tenant remains, mall still scores
        // from accumulated memory. Pre-Prompt-13 the activeTenants<2
        // gate would zero everything.
        var s = freshState()
        for i in s.stores.indices { s.stores[i].tier = .vacant }
        // Plant a single standard tenant.
        s.stores[0].tier = .standard
        s.stores[0].name = "Holdout"
        // Seed a high-memory artifact.
        s.artifacts[0].memoryWeight = 100.0
        s.artifacts[0].condition = 4

        XCTAssertGreaterThan(Scoring.monthlyScore(s), 0,
                             "one-tenant mall with memory must still score")
    }

    func testVacancyRequiresTwoTenants() {
        // One tenant, zero memory — vacancy should be gated off, total = 0.
        var s = freshState()
        for i in s.stores.indices { s.stores[i].tier = .vacant }
        s.stores[0].tier = .standard
        s.stores[0].name = "Holdout"
        for i in s.artifacts.indices { s.artifacts[i].memoryWeight = 0 }
        XCTAssertEqual(Scoring.monthlyScore(s), 0,
                       "vacancy is strict-gated; no memory means no score at 1 tenant")
    }

    func testVacancyRequiresThirtyTraffic() {
        // Starting mall, memory zero, traffic below threshold.
        // activeTenants >= 2 satisfied, but traffic gate fails.
        var s = freshState()
        s.currentTraffic = 20
        for i in s.artifacts.indices { s.artifacts[i].memoryWeight = 0 }
        XCTAssertEqual(Scoring.monthlyScore(s), 0,
                       "vacancy traffic gate still active; memory is 0 so total 0")
    }

    func testMemoryScoresEvenAtLowTraffic() {
        // Traffic below the 30 vacancy-gate, but memory should still
        // contribute (damped by lifeMult but not hard-zeroed).
        var s = freshState()
        s.currentTraffic = 15   // lifeMult = 0.15
        s.artifacts[0].memoryWeight = 100
        s.artifacts[0].condition = 0

        // memory contribution = 100 × stateMult(thriving 1.0) × yearMult(1) × life(0.15) = 15
        // vacancy contribution = 0 (traffic < 30 gate)
        XCTAssertEqual(Scoring.monthlyScore(s), 15)
    }
}

// MARK: - actionBurst table

final class ActionBurstTests: XCTestCase {

    private func stateAtEnv(_ env: EnvironmentState) -> GameState {
        var s = freshState()
        switch env {
        case .thriving:    setOccupancy(&s, ratio: 0.95)
        case .fading:      setOccupancy(&s, ratio: 0.75)
        case .struggling:  setOccupancy(&s, ratio: 0.55)
        case .dying:       setOccupancy(&s, ratio: 0.30)
        case .dead:        setOccupancy(&s, ratio: 0.10)
        case .ghostMall:
            setOccupancy(&s, ratio: 0.10)
            s.monthsInDeadState = 60   // flips .dead → .ghostMall
        }
        XCTAssertEqual(EnvironmentState.from(s), env, "precondition failed")
        return s
    }

    func testBurstCurveMatchesSpec() {
        let expected: [(EnvironmentState, Int)] = [
            (.thriving, 0),
            (.fading, 0),
            (.struggling, 10),
            (.dying, 25),
            (.dead, 40),
            (.ghostMall, 50),
        ]
        for (env, value) in expected {
            XCTAssertEqual(Scoring.actionBurst(for: stateAtEnv(env)), value,
                           "burst at \(env.rawValue) should be \(value)")
        }
    }
}

// MARK: - Curation action bursts integrated

final class CurationBurstIntegrationTests: XCTestCase {

    // Helper: close a tenant, return the new state + the spawned boarded id.
    private func closeTenant(_ s: GameState, at slotId: Int) -> (GameState, Int) {
        var state = s
        guard let i = state.stores.firstIndex(where: { $0.id == slotId }) else {
            return (state, -1)
        }
        state = TenantLifecycle.vacateSlot(storeIndex: i, state: state)
        let aid = state.artifacts.first(where: { $0.storeSlotId == slotId })!.id
        return (state, aid)
    }

    func testSealStorefrontAddsBurst() {
        var s = freshState()
        setOccupancy(&s, ratio: 0.30)   // dying, burst = 25
        // Close a tenant so there's a boardedStorefront to seal.
        let slotId = s.stores.first(where: { $0.tier != .vacant && $0.tier != .anchor })!.id
        let (s2, aid) = closeTenant(s, at: slotId)
        let before = s2.score

        let after = ArtifactActions.sealStorefront(artifactId: aid, s2)
        XCTAssertEqual(after.score - before, 25,
                       "seal at dying should add a burst of 25")
    }

    func testPlaceArtifactAddsBurst() {
        var s = freshState()
        setOccupancy(&s, ratio: 0.10)
        s.monthsInDeadState = 60   // ghostMall, burst = 50
        s.cash = 100_000

        let before = s.score
        let after = ArtifactActions.place(type: .kugelBall,
                                           at: (x: 500, y: 700), s)
        XCTAssertEqual(after.score - before, 50,
                       "placement at ghostMall should add a burst of 50")
    }

    func testRepurposeAsDisplayAddsBurst() {
        var s = freshState()
        setOccupancy(&s, ratio: 0.55)   // struggling, burst = 10
        let slotId = s.stores.first(where: { $0.tier != .vacant && $0.tier != .anchor })!.id
        let (s2, aid) = closeTenant(s, at: slotId)
        let before = s2.score

        let after = ArtifactActions.repurposeAsDisplay(
            artifactId: aid, content: .historicalPlaque, s2)
        XCTAssertEqual(after.score - before, 10,
                       "repurpose at struggling should add a burst of 10")
    }

    func testRevertToBoardedIsScoreNeutral() {
        var s = freshState()
        setOccupancy(&s, ratio: 0.30)
        let slotId = s.stores.first(where: { $0.tier != .vacant && $0.tier != .anchor })!.id
        var (s2, aid) = closeTenant(s, at: slotId)
        s2 = ArtifactActions.repurposeAsDisplay(
            artifactId: aid, content: .historicalPlaque, s2)
        let before = s2.score

        let after = ArtifactActions.revertToBoarded(artifactId: aid, s2)
        XCTAssertEqual(after.score, before,
                       "revert is un-curation — neither rewarded nor penalized")
    }

    func testThrivingActionsNoBurst() {
        // At thriving, curation is burst-free (multiplier == 1.0).
        var s = freshState()
        s.cash = 100_000
        XCTAssertEqual(EnvironmentState.from(s), .thriving)
        let before = s.score
        let after = ArtifactActions.place(type: .kugelBall,
                                           at: (x: 500, y: 700), s)
        XCTAssertEqual(after.score - before, 0,
                       "thriving placement adds no burst — 'memory supplements' only at decline")
    }
}

// MARK: - Memory weight decay

final class MemoryDecayTests: XCTestCase {

    func testMonthsSinceLastThoughtStartsAtZero() {
        let s = StartingMall.initialState()
        for a in s.artifacts {
            XCTAssertEqual(a.monthsSinceLastThought, 0)
        }
    }

    func testCounterIncrementsEachTick() {
        var s = freshState()
        s.artifacts[0].memoryWeight = 50
        let id0 = s.artifacts[0].id

        var rng = SeededGenerator(seed: 1)
        for expectedMonths in 1...5 {
            s = TickEngine.tick(s, rng: &rng)
            let a = s.artifacts.first(where: { $0.id == id0 })!
            XCTAssertEqual(a.monthsSinceLastThought, expectedMonths)
            // Below threshold — memoryWeight preserved.
            XCTAssertEqual(a.memoryWeight, 50, accuracy: 0.001)
        }
    }

    func testDecayKicksInAfterSixMonths() {
        var s = freshState()
        s.artifacts[0].memoryWeight = 100
        let id0 = s.artifacts[0].id

        var rng = SeededGenerator(seed: 1)
        // Tick 6 times — on the 6th tick, counter reaches 6 and decay fires
        // that same tick (applying 5% loss).
        for _ in 0..<6 {
            s = TickEngine.tick(s, rng: &rng)
        }
        let a = s.artifacts.first(where: { $0.id == id0 })!
        XCTAssertEqual(a.monthsSinceLastThought, 6)
        // 100 × 0.95 = 95
        XCTAssertEqual(a.memoryWeight, 95, accuracy: 0.001,
                       "first decay tick reduces weight by 5%")
    }

    func testContinuedNeglectCompoundsDecay() {
        var s = freshState()
        s.artifacts[0].memoryWeight = 100
        let id0 = s.artifacts[0].id

        var rng = SeededGenerator(seed: 1)
        // 12 ticks total: 6 below threshold + 6 decaying.
        for _ in 0..<12 {
            s = TickEngine.tick(s, rng: &rng)
        }
        // Expected weight after 6 decay ticks at 5% each: 100 × 0.95^6 ≈ 73.51
        let a = s.artifacts.first(where: { $0.id == id0 })!
        let expected = 100.0 * pow(0.95, 6)
        XCTAssertEqual(a.memoryWeight, expected, accuracy: 0.01)
    }

    func testRecordThoughtFiredResetsCounter() {
        let vm = GameViewModel(seed: 1)
        vm.state = freshState()
        vm.state.artifacts[0].monthsSinceLastThought = 10
        let id0 = vm.state.artifacts[0].id

        vm.recordThoughtFired(artifactId: id0, cohort: .explorers)

        XCTAssertEqual(vm.state.artifacts[0].monthsSinceLastThought, 0,
                       "any thought fire refreshes the 'lived-in' counter")
    }

    func testMemoryWeightAsymptotesButNeverGoesNegative() {
        var s = freshState()
        s.artifacts[0].memoryWeight = 10
        let id0 = s.artifacts[0].id

        var rng = SeededGenerator(seed: 1)
        // Long neglect — 100 ticks total.
        for _ in 0..<100 {
            s = TickEngine.tick(s, rng: &rng)
        }
        let a = s.artifacts.first(where: { $0.id == id0 })!
        XCTAssertGreaterThanOrEqual(a.memoryWeight, 0,
                                     "decay is multiplicative; never below 0")
        XCTAssertLessThan(a.memoryWeight, 0.1,
                          "after 94 decay ticks at 5%/tick, weight approaches 0")
    }
}
