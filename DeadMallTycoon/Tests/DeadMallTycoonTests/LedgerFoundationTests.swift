import XCTest
@testable import DeadMallTycoon

// v9 Prompt 9 Phase A coverage. Every new LedgerEntry case gets:
//   - a Codable roundtrip guard (so future struct additions don't silently
//     drop fields from persistence)
//   - at least one emission-path test (the thing that's supposed to write
//     the entry actually writes it)
//
// Design contract pinned here: .artifactCreated fires ONLY from non-closure
// paths. Closures are covered by .closure or .anchorDeparture; they do NOT
// spawn an additional .artifactCreated entry.

// MARK: - Helpers (local to these tests)

private func plantTenant(_ state: GameState, at slotId: Int,
                         name: String, tier: StoreTier = .standard,
                         traffic: Int = 60, threshold: Int = 30,
                         lease: Int = 24, monthsOccupied: Int = 36) -> GameState {
    var s = state
    guard let i = s.stores.firstIndex(where: { $0.id == slotId }) else { return s }
    let pos = s.stores[i].position
    s.stores[i] = Store(
        id: slotId, name: name, tier: tier,
        rent: 1000, originalRent: 1000, rentMultiplier: 1.0,
        traffic: traffic, threshold: threshold, lease: lease,
        hardship: 0, closing: false, leaving: false,
        monthsOccupied: monthsOccupied, monthsVacant: 0, promotionActive: false,
        position: pos
    )
    return s
}

// MARK: - Codable roundtrip

final class LedgerEntryCodableTests: XCTestCase {

    func testNewCasesRoundTripThroughCodable() throws {
        let entries: [LedgerEntry] = [
            .artifactCreated(
                artifactId: 7, name: "Fountain", type: .fountain,
                origin: .playerAction("placed"), year: 1985, month: 3),
            .decayTransition(
                artifactId: 7, name: "Fountain", type: .fountain,
                fromCondition: 1, toCondition: 2, year: 1987, month: 9),
            .artifactDestroyed(
                artifactId: 7, name: "Fountain", type: .fountain,
                reason: "flood", year: 1989, month: 2),
            .envTransition(
                from: .thriving, to: .fading, year: 1985, month: 6),
            .anchorDeparture(
                tenantName: "Halvorsen", wing: .north,
                trafficDelta: -300,
                coincidentClosureNames: ["Ricky's Records", "Sole Center"],
                yearsOpen: 12, slotId: 1, year: 1991, month: 4),
            .attentionMilestone(
                artifactId: 9, name: "Kugel Ball", type: .kugelBall,
                threshold: 100, year: 1993, month: 8),
        ]
        for entry in entries {
            let data = try JSONEncoder().encode(entry)
            let back = try JSONDecoder().decode(LedgerEntry.self, from: data)
            XCTAssertEqual(back, entry)
        }
    }
}

// MARK: - .artifactCreated

final class ArtifactCreatedEmissionTests: XCTestCase {

    func testPlaceEmitsArtifactCreated() {
        var s = StartingMall.initialState()
        s.cash = 50_000
        s = ArtifactActions.place(type: .kugelBall, at: (x: 500, y: 700), s)

        let entries = s.ledger.filter { $0.isArtifactCreated }
        XCTAssertEqual(entries.count, 1)
        if case .artifactCreated(let aid, let name, let type, let origin, _, _) = entries.first! {
            XCTAssertEqual(type, .kugelBall)
            XCTAssertEqual(name, "Kugel Ball")
            if case .playerAction(let tag) = origin {
                XCTAssertEqual(tag, "placed")
            } else { XCTFail("expected .playerAction origin") }
            XCTAssertTrue(s.artifacts.contains { $0.id == aid },
                          "the entry references the just-placed artifact")
        } else { XCTFail("expected .artifactCreated") }
    }

    // CRITICAL design contract — closure-spawned memorials are covered by
    // .closure / .anchorDeparture only. A second .artifactCreated entry
    // would be redundant and is deliberately not emitted.
    func testVacateSlotDoesNotEmitArtifactCreated() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Brinkerhoff Books")
        s = TenantLifecycle.vacateSlot(storeIndex: 2, state: s)

        XCTAssertFalse(s.ledger.contains { $0.isArtifactCreated },
                       "vacateSlot must NOT emit .artifactCreated — the .closure entry narrates the memorial spawn")
    }

    func testStartingMallHasEmptyLedger() {
        let s = StartingMall.initialState()
        XCTAssertTrue(s.ledger.isEmpty,
                      "starting-seed artifacts must NOT emit .artifactCreated")
    }
}

// MARK: - .anchorDeparture

final class AnchorDepartureEmissionTests: XCTestCase {

    func testAnchorEmitsAnchorDepartureWithWingAndTraffic() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 1, name: "Halvorsen",
                        tier: .anchor, traffic: 300,
                        monthsOccupied: 120)
        let idx = s.stores.firstIndex(where: { $0.id == 1 })!
        let wing = s.stores[idx].wing

        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        guard case .anchorDeparture(let name, let w, let delta, _,
                                     let yearsOpen, let slotId, _, _) = s.ledger.last!
        else { return XCTFail("expected .anchorDeparture last entry") }
        XCTAssertEqual(name, "Halvorsen")
        XCTAssertEqual(w, wing)
        XCTAssertEqual(delta, -300, "traffic delta is negative — the mall loses what the anchor brought")
        XCTAssertEqual(yearsOpen, 10, "120 monthsOccupied → 10 yearsOpen")
        XCTAssertEqual(slotId, 1)
    }

    func testNonAnchorEmitsClosureNotAnchorDeparture() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Brinkerhoff Books", tier: .standard)
        s = TenantLifecycle.vacateSlot(storeIndex: 2, state: s)

        XCTAssertTrue(s.ledger.contains { $0.isClosure })
        XCTAssertFalse(s.ledger.contains { $0.isAnchorDeparture })
    }

    func testAnchorCoincidentClosuresListedWhenMultipleCloseSameTick() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        // Anchor (slot 1 is the north anchor in starting seed).
        if let i = s.stores.firstIndex(where: { $0.tier == .anchor }) {
            s.stores[i].closing = true
        }
        // Two standards also set to close this tick.
        let standardIdxs = Array(s.stores.indices.filter { s.stores[$0].tier == .standard }.prefix(2))
        let standardNames = standardIdxs.map { s.stores[$0].name }
        for i in standardIdxs { s.stores[i].closing = true }

        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)

        guard let anchorEntry = s.ledger.first(where: { $0.isAnchorDeparture }) else {
            return XCTFail("expected .anchorDeparture in the ledger")
        }
        guard case .anchorDeparture(_, _, _, let coincident, _, _, _, _) = anchorEntry
        else { return XCTFail("pattern-match on .anchorDeparture") }
        XCTAssertEqual(Set(coincident), Set(standardNames),
                       "the two standards closing alongside the anchor are captured as coincident names")
    }

    func testEvictOnAnchorAlsoEmitsAnchorDeparture() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 1, name: "Halvorsen", tier: .anchor)
        s.score = 1000
        s = StoreActions.evict(storeId: 1, s)

        XCTAssertTrue(s.ledger.contains { $0.isAnchorDeparture },
                      "player-driven anchor eviction also routes through the anchor-departure ledger case")
    }
}

// MARK: - .decayTransition

final class DecayTransitionEmissionTests: XCTestCase {

    func testDecayTransitionFiresWhenArtifactConditionAdvances() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s.cash = 50_000
        // Place one decaying artifact (cost > 0 types are eligible).
        s = ArtifactActions.place(type: .kugelBall, at: (x: 500, y: 700), s)

        // Tick 400 months with seed 42. Per-tick decay chance at condition 0
        // is 0.02; over 400 ticks the probability of at least one fire is
        // 1 - 0.98^400 ≈ 99.97%. For a seeded run, the outcome is
        // deterministic — the assertion is firm, not statistical.
        var rng = SeededGenerator(seed: 42)
        for _ in 0..<400 {
            s = TickEngine.tick(s, rng: &rng)
        }

        let decayEntries = s.ledger.filter { $0.isDecayTransition }
        XCTAssertFalse(decayEntries.isEmpty,
                       "400 ticks on placed artifacts must produce at least one .decayTransition")
        // Every entry should step condition by exactly one. Type isn't
        // pinned because the starting mall also seeds 5 decaying artifacts;
        // which one fires first depends on rng/seed ordering.
        for entry in decayEntries {
            if case .decayTransition(_, _, _, let from, let to, _, _) = entry {
                XCTAssertEqual(to - from, 1,
                               "each entry represents exactly one condition step")
            }
        }
    }

    func testMemorialArtifactsDoNotDecay() {
        // boardedStorefront has cost == 0 in the catalog → the decay loop's
        // guard skips it → no .decayTransition ever fires for a boarded
        // storefront no matter how long it sits.
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s = plantTenant(s, at: 2, name: "Brinkerhoff Books")
        s = TenantLifecycle.vacateSlot(storeIndex: 2, state: s)
        let memorialId = s.artifacts.first { $0.type == .boardedStorefront }!.id

        var rng = SeededGenerator(seed: 1)
        for _ in 0..<300 { s = TickEngine.tick(s, rng: &rng) }

        let memorialDecays = s.ledger.compactMap { entry -> Int? in
            if case .decayTransition(let aid, _, _, _, _, _, _) = entry, aid == memorialId {
                return aid
            }
            return nil
        }
        XCTAssertTrue(memorialDecays.isEmpty,
                      "memorial artifacts (ambient types) are frozen and must not produce decay entries")
    }
}

// MARK: - .envTransition

final class EnvTransitionEmissionTests: XCTestCase {

    func testEnvTransitionFiresWhenBandChangesAcrossTick() {
        // StartingMall occupancy = 16/18 ≈ 0.889 → .thriving.
        // Vacating one standard drops it to 15/18 ≈ 0.833 → .fading.
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        XCTAssertEqual(EnvironmentState.from(s), .thriving,
                       "precondition: starting state is thriving")

        if let i = s.stores.firstIndex(where: { $0.tier == .standard }) {
            s.stores[i].closing = true
        }
        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)

        let transitions = s.ledger.filter { $0.isEnvTransition }
        XCTAssertEqual(transitions.count, 1, "exactly one env transition per tick")
        if case .envTransition(let from, let to, _, _) = transitions.first! {
            XCTAssertEqual(from, .thriving)
            XCTAssertEqual(to, .fading)
        }
    }

    func testEnvTransitionSuppressedWhenStateUnchanged() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)

        XCTAssertFalse(s.ledger.contains { $0.isEnvTransition },
                       "a tick that doesn't cross a state band must not emit envTransition")
    }
}

// MARK: - .attentionMilestone

final class AttentionMilestoneEmissionTests: XCTestCase {

    private func firePlacedMemorial(vm: GameViewModel) -> Int {
        vm.state = StartingMall.initialState()
        vm.state = plantTenant(vm.state, at: 2, name: "Brinkerhoff Books")
        vm.state = TenantLifecycle.vacateSlot(storeIndex: 2, state: vm.state)
        return vm.state.artifacts.first { $0.type == .boardedStorefront }!.id
    }

    func testFirstMilestoneFiresAtTen() {
        let vm = GameViewModel(seed: 1)
        let aid = firePlacedMemorial(vm: vm)

        for _ in 0..<9 { vm.recordThoughtFired(artifactId: aid, cohort: .explorers) }
        XCTAssertTrue(vm.state.ledger.filter { $0.isAttentionMilestone }.isEmpty,
                      "no milestone fires before count == 10")

        vm.recordThoughtFired(artifactId: aid, cohort: .explorers)
        let milestones = vm.state.ledger.filter { $0.isAttentionMilestone }
        XCTAssertEqual(milestones.count, 1)
        if case .attentionMilestone(_, _, _, let t, _, _) = milestones.first! {
            XCTAssertEqual(t, 10)
        }
    }

    func testMilestonesFireInOrderAtConfiguredThresholds() {
        let vm = GameViewModel(seed: 1)
        let aid = firePlacedMemorial(vm: vm)
        // Cap to the 100 threshold (faster) — 500/1000 take too long to
        // simulate in a unit test, but the code path is identical.
        for _ in 0..<100 { vm.recordThoughtFired(artifactId: aid, cohort: .explorers) }

        let thresholds = vm.state.ledger.compactMap { entry -> Int? in
            if case .attentionMilestone(_, _, _, let t, _, _) = entry { return t }
            return nil
        }
        XCTAssertEqual(thresholds, [10, 50, 100],
                       "each configured threshold ≤ 100 fires exactly once, in order")
    }

    func testIntermediateCountsDoNotRefire() {
        // Explicitly — firing thoughts past a threshold doesn't re-emit.
        let vm = GameViewModel(seed: 1)
        let aid = firePlacedMemorial(vm: vm)
        for _ in 0..<20 { vm.recordThoughtFired(artifactId: aid, cohort: .explorers) }
        let milestones = vm.state.ledger.filter { $0.isAttentionMilestone }
        XCTAssertEqual(milestones.count, 1,
                       "firing past 10 to 20 must not re-emit the 10-threshold entry")
    }
}

// MARK: - LedgerTemplates rendering coverage

final class LedgerTemplateRenderingTests: XCTestCase {

    // Every case must return a non-empty rendered line so the ledger UI
    // never gets a blank row.
    func testEveryCaseRendersANonEmptyLine() {
        let samples: [LedgerEntry] = [
            .closure(ClosureEvent(id: UUID(), tenantName: "X", tenantTier: .standard,
                                   yearsOpen: 2, slotId: 1, year: 1985, month: 3)),
            .offerDestruction(tenantName: "X", newTenantName: "Y", yearsBoarded: 1,
                               memoryWeight: 0, thoughtReferenceCount: 0,
                               year: 1986, month: 4),
            .artifactSealed(tenantName: "X", sourceType: .boardedStorefront,
                             memoryWeight: 0, thoughtReferenceCount: 0,
                             year: 1987, month: 5),
            .displayConversion(tenantName: "X", content: .historicalPlaque,
                                memoryWeight: 0, thoughtReferenceCount: 0,
                                year: 1988, month: 6),
            .displayReverted(tenantName: "X", content: .historicalPlaque,
                              memoryWeight: 0, thoughtReferenceCount: 0,
                              year: 1989, month: 7),
            .artifactCreated(artifactId: 1, name: "Fountain", type: .fountain,
                              origin: .playerAction("placed"), year: 1990, month: 8),
            .decayTransition(artifactId: 1, name: "Fountain", type: .fountain,
                              fromCondition: 0, toCondition: 1, year: 1991, month: 9),
            .artifactDestroyed(artifactId: 1, name: "Fountain", type: .fountain,
                                reason: "flood", year: 1992, month: 10),
            .envTransition(from: .thriving, to: .fading, year: 1993, month: 11),
            .anchorDeparture(tenantName: "Halvorsen", wing: .north,
                              trafficDelta: -300, coincidentClosureNames: ["A"],
                              yearsOpen: 12, slotId: 1, year: 1994, month: 0),
            .attentionMilestone(artifactId: 1, name: "Kugel Ball",
                                 type: .kugelBall, threshold: 100,
                                 year: 1995, month: 1),
        ]
        for entry in samples {
            let line = LedgerTemplates.line(for: entry)
            XCTAssertFalse(line.isEmpty, "every case must produce a rendered line")
        }
    }

    func testMonthYearFormatter() {
        XCTAssertEqual(LedgerTemplates.monthYear(0, 1985), "January 1985")
        XCTAssertEqual(LedgerTemplates.monthYear(11, 1995), "December 1995")
    }
}
