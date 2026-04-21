import XCTest
@testable import DeadMallTycoon

// v9: Prompt 2 coverage. Every tenant → vacant transition must spawn a
// boardedStorefront artifact capturing the tenant's name, year, and slot. The
// artifact is additional, not replacing — mechanic state (scoring, hardship,
// leases, threat) is unchanged.

// MARK: - Helpers

private func autoDismiss(_ s: inout GameState) {
    if s.decision != nil { s.decision = nil; s.paused = false }
}

/// Pin a tenant to a specific slot so tests can reason about known-good
/// name/position without relying on the default StartingMall seed arrangement.
private func plantTenant(_ state: GameState, at slotId: Int,
                         name: String, tier: StoreTier = .standard,
                         traffic: Int = 60, threshold: Int = 30,
                         lease: Int = 24) -> GameState {
    var s = state
    guard let i = s.stores.firstIndex(where: { $0.id == slotId }) else { return s }
    let pos = s.stores[i].position
    s.stores[i] = Store(
        id: slotId, name: name, tier: tier,
        rent: 1000, originalRent: 1000, rentMultiplier: 1.0,
        traffic: traffic, threshold: threshold, lease: lease,
        hardship: 0, closing: false, leaving: false,
        monthsOccupied: 0, monthsVacant: 0, promotionActive: false,
        position: pos
    )
    return s
}

// MARK: - Direct TenantLifecycle tests

final class TenantLifecycleTests: XCTestCase {

    func testVacateSlotProducesBoardedStorefrontArtifact() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Waldenbooks")
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!

        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        XCTAssertEqual(s.artifacts.count, 1)
        let a = s.artifacts[0]
        XCTAssertEqual(a.type, .boardedStorefront)
        XCTAssertEqual(a.name, "Waldenbooks", "name stores literal tenant name, no Old/Former prefix")
        XCTAssertEqual(a.yearCreated, s.year)
        XCTAssertEqual(a.storeSlotId, 2)
        XCTAssertNil(a.tenantId, "tenantId is reserved for a future prompt; nil in Prompt 2")
        if case .tenant(let who) = a.origin {
            XCTAssertEqual(who, "Waldenbooks")
        } else {
            XCTFail("expected .tenant origin, got \(a.origin)")
        }
        XCTAssertEqual(a.condition, 0)
        XCTAssertEqual(a.memoryWeight, 0)
    }

    func testVacateSlotTransitionsStoreToVacant() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 5, name: "Claire's")
        let idx = s.stores.firstIndex(where: { $0.id == 5 })!

        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        XCTAssertEqual(s.stores[idx].tier, .vacant,
                       "slot must actually become vacant — artifact is additional, not replacing")
        XCTAssertEqual(s.stores[idx].name, "")
        XCTAssertEqual(s.stores[idx].rent, 0)
    }

    func testVacateSlotOnAlreadyVacantIsDefensiveNoOp() {
        var s = StartingMall.initialState()
        // Slot 13 in the seed is vacant.
        let idx = s.stores.firstIndex(where: { $0.tier == .vacant })!

        let beforeArtifactCount = s.artifacts.count
        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)
        XCTAssertEqual(s.artifacts.count, beforeArtifactCount,
                       "no artifact should be generated for an already-vacant slot")
    }

    func testMultipleVacationsAccumulateUniqueArtifacts() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 1, name: "Sam Goody")
        s = plantTenant(s, at: 2, name: "Waldenbooks")
        s = plantTenant(s, at: 3, name: "Foot Locker")

        s = TenantLifecycle.vacateSlot(storeIndex: 1, state: s)
        s = TenantLifecycle.vacateSlot(storeIndex: 2, state: s)
        s = TenantLifecycle.vacateSlot(storeIndex: 3, state: s)

        XCTAssertEqual(s.artifacts.count, 3)
        let names = Set(s.artifacts.map(\.name))
        XCTAssertEqual(names, ["Sam Goody", "Waldenbooks", "Foot Locker"])
        let ids = Set(s.artifacts.map(\.id))
        XCTAssertEqual(ids.count, 3, "artifact ids must be unique")
    }

    func testYearOfCreationMatchesStateYearAtClosure() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 1, name: "Sam Goody")
        s.year = 1987
        s = TenantLifecycle.vacateSlot(storeIndex: 1, state: s)
        XCTAssertEqual(s.artifacts[0].yearCreated, 1987)
    }
}

// MARK: - TickEngine-driven closure paths

final class HardshipClosureSpawnsArtifactTests: XCTestCase {

    func testClosingFlagTransitionSpawnsArtifact() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s = plantTenant(s, at: 1, name: "Sam Goody")
        // Pre-set closing so the next tick will execute the closing branch.
        if let i = s.stores.firstIndex(where: { $0.id == 1 }) {
            s.stores[i].closing = true
        }

        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        autoDismiss(&s)

        let samArtifacts = s.artifacts.filter { $0.name == "Sam Goody" }
        XCTAssertEqual(samArtifacts.count, 1, "hardship-driven closure must produce an artifact")
        XCTAssertEqual(samArtifacts.first?.storeSlotId, 1)
    }

    func testLeavingFlagTransitionSpawnsArtifact() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s = plantTenant(s, at: 2, name: "Waldenbooks")
        if let i = s.stores.firstIndex(where: { $0.id == 2 }) {
            s.stores[i].leaving = true
        }

        var rng = SeededGenerator(seed: 2)
        s = TickEngine.tick(s, rng: &rng)
        autoDismiss(&s)

        let wb = s.artifacts.filter { $0.name == "Waldenbooks" }
        XCTAssertEqual(wb.count, 1, "lease non-renewal (leaving) must produce an artifact")
        XCTAssertEqual(wb.first?.storeSlotId, 2)
    }
}

final class ForceEvictionSpawnsArtifactTests: XCTestCase {

    func testEvictionSpawnsArtifactAndVacatesSlot() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 5, name: "Claire's")

        s = StoreActions.evict(storeId: 5, s)

        let c = s.artifacts.filter { $0.name == "Claire's" }
        XCTAssertEqual(c.count, 1, "force-eviction must produce an artifact")
        XCTAssertEqual(c.first?.storeSlotId, 5)
        if let i = s.stores.firstIndex(where: { $0.id == 5 }) {
            XCTAssertEqual(s.stores[i].tier, .vacant)
        } else {
            XCTFail("slot 5 must still exist after eviction")
        }
    }

    func testEvictionOriginIsTenantName() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 6, name: "Radio Shack")
        s = StoreActions.evict(storeId: 6, s)
        let a = s.artifacts.first { $0.name == "Radio Shack" }
        XCTAssertNotNil(a)
        if case .tenant(let who) = a!.origin {
            XCTAssertEqual(who, "Radio Shack")
        } else {
            XCTFail("expected .tenant origin, got \(String(describing: a?.origin))")
        }
    }
}

// MARK: - Regression guards — Prompt 2 does NOT alter mechanics

final class Prompt2RegressionTests: XCTestCase {

    // Artifact presence must be invisible to Scoring. Pin two states that
    // differ only in state.artifacts and assert identical monthly score.
    func testScoringIgnoresArtifactsPresence() {
        var base = StartingMall.initialState()
        base.pendingLawsuitMonth = nil
        base.currentTraffic = 120
        // Force 2 slots vacant so Scoring has something to award.
        for i in base.stores.indices where [10, 11].contains(base.stores[i].id) {
            base.stores[i] = Store.vacant(id: base.stores[i].id, at: base.stores[i].position)
        }
        let cleanScore = Scoring.monthlyScore(base)

        var withArtifacts = base
        for n in 0..<5 {
            withArtifacts.artifacts.append(ArtifactFactory.make(
                id: n + 1, type: .boardedStorefront,
                name: "Test\(n)", origin: .tenant(name: "Test\(n)"),
                yearCreated: withArtifacts.year, storeSlotId: n
            ))
        }
        let artifactScore = Scoring.monthlyScore(withArtifacts)

        XCTAssertEqual(cleanScore, artifactScore,
                       "Prompt 2 must not let artifact presence affect scoring")
    }

    // A full year with no closures must leave the artifact list empty.
    // Uses plant-a-healthy-mall so no natural closure fires.
    func testNoClosuresMeansNoArtifactsInPrompt2() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        // Replace every non-anchor slot with a healthy, long-lease tenant so
        // nothing goes closing/leaving naturally in a year. Anchors already
        // have long leases in the seed.
        for i in s.stores.indices where s.stores[i].tier != .anchor {
            let pos = s.stores[i].position
            s.stores[i] = Store(
                id: s.stores[i].id, name: "HealthyCo", tier: .standard,
                rent: 1000, originalRent: 1000, rentMultiplier: 1.0,
                traffic: 80, threshold: 20, lease: 120,
                hardship: 0, closing: false, leaving: false,
                monthsOccupied: 0, monthsVacant: 0, promotionActive: false,
                position: pos
            )
        }
        var rng = SeededGenerator(seed: 1234)
        for _ in 0..<12 {
            s = TickEngine.tick(s, rng: &rng)
            autoDismiss(&s)
        }
        XCTAssertTrue(s.artifacts.isEmpty,
                      "no closure path → no artifacts spawned")
    }

    // Deterministic-seed sanity: the same seed across two runs produces the
    // same artifact set (order and contents).
    func testArtifactSpawnIsDeterministicUnderSameSeed() {
        func run(seed: UInt64) -> [String] {
            var s = StartingMall.initialState()
            s.pendingLawsuitMonth = nil
            var rng = SeededGenerator(seed: seed)
            for _ in 0..<36 {
                s = TickEngine.tick(s, rng: &rng)
                autoDismiss(&s)
            }
            return s.artifacts.map { "\($0.id):\($0.name):\($0.yearCreated):\($0.storeSlotId ?? -1)" }
        }
        XCTAssertEqual(run(seed: 77), run(seed: 77))
    }
}
