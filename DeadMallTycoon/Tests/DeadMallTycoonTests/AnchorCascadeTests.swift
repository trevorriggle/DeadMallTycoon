import XCTest
@testable import DeadMallTycoon

// v9 Prompt 10 Phase A coverage. Anchor closures trigger the wing-cascade:
//   - 3 cluster artifacts spawn at fixed wing-relative coords
//   - wingTrafficMultipliers[wing] = 0.75 (permanent 25% drop)
//   - wingEnvOffsets[wing] += 1 (wing ages one band faster)
//   - pendingWingHardshipMonths[wing] = 3 (staggered hardship wave)
//   - anchorDepartedWings includes the wing (idempotency flag)
// Non-anchor closures trigger none of the above.

// MARK: - Helpers

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

private func vacateFirstAnchor(in state: GameState) -> (GameState, Wing) {
    var s = state
    guard let idx = s.stores.firstIndex(where: { $0.tier == .anchor }) else {
        preconditionFailure("no anchor in starting seed")
    }
    let wing = s.stores[idx].wing
    s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)
    return (s, wing)
}

// MARK: - Wing state fields

final class AnchorCascadeWingStateTests: XCTestCase {

    func testFreshStateHasNoCascadeEffectsSet() {
        let s = StartingMall.initialState()
        XCTAssertEqual(s.wingTrafficMultipliers[.north], 1.0)
        XCTAssertEqual(s.wingTrafficMultipliers[.south], 1.0)
        XCTAssertEqual(s.wingEnvOffsets[.north], 0)
        XCTAssertEqual(s.wingEnvOffsets[.south], 0)
        XCTAssertEqual(s.pendingWingHardshipMonths[.north], 0)
        XCTAssertEqual(s.pendingWingHardshipMonths[.south], 0)
        XCTAssertTrue(s.anchorDepartedWings.isEmpty)
    }

    func testAnchorVacateSetsAllWingFields() {
        let (s, wing) = vacateFirstAnchor(in: StartingMall.initialState())
        XCTAssertEqual(s.wingTrafficMultipliers[wing], 0.75,
                       "wing traffic drops 25% permanently on anchor departure")
        XCTAssertEqual(s.wingEnvOffsets[wing], 1,
                       "wing env offset bumps +1 band")
        XCTAssertEqual(s.pendingWingHardshipMonths[wing], 3,
                       "hardship stagger is 3 months")
        XCTAssertTrue(s.anchorDepartedWings.contains(wing))
    }

    func testOtherWingUnaffected() {
        let (s, wing) = vacateFirstAnchor(in: StartingMall.initialState())
        let otherWing: Wing = (wing == .north) ? .south : .north
        XCTAssertEqual(s.wingTrafficMultipliers[otherWing], 1.0,
                       "opposite wing's traffic unchanged")
        XCTAssertEqual(s.wingEnvOffsets[otherWing], 0)
        XCTAssertEqual(s.pendingWingHardshipMonths[otherWing], 0)
        XCTAssertFalse(s.anchorDepartedWings.contains(otherWing))
    }

    func testNonAnchorClosureDoesNotTriggerCascade() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Brinkerhoff Books", tier: .standard)
        s = TenantLifecycle.vacateSlot(storeIndex: 2, state: s)
        XCTAssertTrue(s.anchorDepartedWings.isEmpty,
                      "standard closure must not flip the anchor-departed flag")
        XCTAssertEqual(s.wingTrafficMultipliers[.north], 1.0)
        XCTAssertEqual(s.wingTrafficMultipliers[.south], 1.0)
        XCTAssertEqual(s.pendingWingHardshipMonths[.north], 0)
        XCTAssertEqual(s.pendingWingHardshipMonths[.south], 0)
    }
}

// MARK: - Cluster artifact spawn

final class AnchorCascadeClusterSpawnTests: XCTestCase {

    func testClusterSpawnsThreeArtifactsBeyondTheMemorial() {
        var s = StartingMall.initialState()
        let baselineArtifactCount = s.artifacts.count
        let (after, _) = vacateFirstAnchor(in: s)
        s = after
        // Expected: baseline + 1 boardedStorefront + 3 cluster = +4
        XCTAssertEqual(s.artifacts.count, baselineArtifactCount + 4)
    }

    func testClusterContainsExpectedArtifactTypes() {
        let (s, _) = vacateFirstAnchor(in: StartingMall.initialState())
        let types = Set(s.artifacts.map(\.type))
        XCTAssertTrue(types.contains(.boardedStorefront),
                      "the anchor slot's own memorial still spawns")
        XCTAssertTrue(types.contains(.stoppedEscalator))
        XCTAssertTrue(types.contains(.lostSignage))
        XCTAssertTrue(types.contains(.skylight),
                      "re-use of .skylight with condition 3 — no new 'deteriorating' type")
    }

    func testSkylightSpawnsAtConditionThree() {
        let (s, _) = vacateFirstAnchor(in: StartingMall.initialState())
        // Find the NEW skylight (cascade origin). StartingMall already
        // seeds a pristine .skylight among the starting artifacts; filter
        // to the event-origin one to disambiguate.
        let cascadeSkylights = s.artifacts.filter { artifact in
            guard artifact.type == .skylight else { return false }
            if case .event = artifact.origin { return true }
            return false
        }
        XCTAssertEqual(cascadeSkylights.count, 1)
        XCTAssertEqual(cascadeSkylights.first?.condition, 3,
                       "cascade skylight spawns already deteriorating")
    }

    func testClusterArtifactsCarryAnchorDepartureEventOrigin() {
        let (s, _) = vacateFirstAnchor(in: StartingMall.initialState())
        let cascadeArtifacts = s.artifacts.filter { artifact in
            [.stoppedEscalator, .lostSignage].contains(artifact.type)
        }
        XCTAssertEqual(cascadeArtifacts.count, 2)
        for a in cascadeArtifacts {
            guard case .event(let name) = a.origin else {
                return XCTFail("expected .event origin on cluster artifact")
            }
            XCTAssertTrue(name.contains("anchor departure"),
                          "origin name references the cascade source")
        }
    }

    func testClusterPositionsAreDeterministicPerWing() {
        // Run twice from identical starting state. Cluster coords should
        // be byte-identical — positions are hand-picked, not randomized.
        let (s1, _) = vacateFirstAnchor(in: StartingMall.initialState())
        let (s2, _) = vacateFirstAnchor(in: StartingMall.initialState())
        let cluster1 = s1.artifacts.filter { $0.type == .stoppedEscalator || $0.type == .lostSignage }
        let cluster2 = s2.artifacts.filter { $0.type == .stoppedEscalator || $0.type == .lostSignage }
        XCTAssertEqual(cluster1.map { [$0.x ?? 0, $0.y ?? 0] },
                       cluster2.map { [$0.x ?? 0, $0.y ?? 0] },
                       "cluster positions are reproducible")
    }
}

// MARK: - Hardship stagger

final class AnchorCascadeHardshipStaggerTests: XCTestCase {

    // Invariant: after the cascade triggers, in-wing non-anchor tenants
    // receive +1 hardship for exactly 3 ticks, then the stagger stops.
    func testHardshipStaggerAppliesForExactlyThreeMonths() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil

        // Snapshot pre-tick hardship on the north wing's non-anchor tenants.
        let northIndices = s.stores.indices.filter {
            s.stores[$0].wing == .north && s.stores[$0].tier != .anchor
                && s.stores[$0].tier != .vacant
        }
        XCTAssertFalse(northIndices.isEmpty)

        // Close the north anchor.
        guard let anchorIdx = s.stores.firstIndex(where: {
            $0.tier == .anchor && $0.wing == .north
        }) else { return XCTFail("expected a north anchor in the seed") }
        s = TenantLifecycle.vacateSlot(storeIndex: anchorIdx, state: s)

        XCTAssertEqual(s.pendingWingHardshipMonths[.north], 3)
        // Capture baseline AFTER cascade apply but BEFORE first tick.
        let baseline = northIndices.map { s.stores[$0].hardship }

        var rng = SeededGenerator(seed: 1)
        // Tick 3 times: each tick should apply +1 to each non-anchor in-wing tenant.
        for expectedMonthsLeft in stride(from: 2, through: 0, by: -1) {
            s = TickEngine.tick(s, rng: &rng)
            XCTAssertEqual(s.pendingWingHardshipMonths[.north], expectedMonthsLeft,
                           "counter decrements each tick")
        }

        // After 3 ticks, the cumulative in-wing hardship on surviving stores
        // is at least baseline+3 (may be higher if traffic pressure also
        // contributed — the cascade is ADDITIVE, not a replacement).
        let afterThree = northIndices.compactMap { idx -> Int? in
            // Some stores may have closed/vacated; skip those.
            guard s.stores[idx].tier != .vacant else { return nil }
            return s.stores[idx].hardship
        }
        // Hardship gains from cascade alone: +3 per store still present.
        // (Traffic-pressure can only ADD, not subtract, when the wing mult
        // is 0.75 — so the delta is lower-bounded by 3 per still-open store.)
        for (i, newHardship) in afterThree.enumerated() {
            XCTAssertGreaterThanOrEqual(newHardship, baseline[i] + 3,
                                         "cascade contributed at least +3 over 3 ticks")
        }

        // Fourth tick: stagger is done, no more cascade-driven +1.
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertEqual(s.pendingWingHardshipMonths[.north], 0)
    }

    func testHardshipStaggerSkipsVacantAndAnchorSlots() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil

        // Manually trigger the cascade without running the main tick flow.
        guard let anchorIdx = s.stores.firstIndex(where: {
            $0.tier == .anchor && $0.wing == .north
        }) else { return XCTFail() }
        s = TenantLifecycle.vacateSlot(storeIndex: anchorIdx, state: s)

        // Record anchor (the OTHER one, south) + vacant pre-state.
        let southAnchorIdx = s.stores.firstIndex(where: {
            $0.tier == .anchor && $0.wing == .south
        })!
        let southAnchorHardshipBefore = s.stores[southAnchorIdx].hardship
        let vacantIdx = s.stores.firstIndex(where: { $0.tier == .vacant })!
        let vacantHardshipBefore = s.stores[vacantIdx].hardship

        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)

        XCTAssertEqual(s.stores[southAnchorIdx].hardship, southAnchorHardshipBefore,
                       "opposite-wing anchor unaffected (wrong wing)")
        XCTAssertEqual(s.stores[vacantIdx].hardship, vacantHardshipBefore,
                       "vacant slots skipped regardless of wing")
    }
}

// MARK: - Wing traffic multiplier

final class AnchorCascadeTrafficMultiplierTests: XCTestCase {

    // Direct test: wing multiplier makes in-wing stores treat mall-wide
    // traffic as 0.75× for hardship calc. Verified by comparing
    // hardship deltas between an anchor-departed wing and the control
    // wing under otherwise identical conditions.
    func testInWingHardshipFeelsTheTrafficDrop() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s.currentTraffic = 80   // a mid value — above the control's threshold, maybe below cascade's

        // Plant two identical tenants, one per wing. Starting seed has
        // these in place; just ensure the threshold is high enough that
        // the wing-mult matters. Use a threshold that's BELOW the raw
        // traffic*2.2 so control accrues no hardship, but ABOVE the 0.75×
        // scaled traffic so the cascaded wing DOES.
        //
        // Math: threshold * 2.2 is the hardship cutoff. With tr=80:
        //   no-mult effective tr = 80.
        //   cascade wing effective tr = 80 * 0.75 = 60.
        // Pick threshold such that threshold*2.2 sits between 60 and 80:
        //   e.g. threshold*2.2 = 70 → threshold ≈ 32.
        // That way: no-mult wing sees 80 >= 70 → hardship decrements;
        //           cascade wing sees 60 < 70 → hardship increments.
        let testThreshold = 32
        // Find a standard in each wing and conform them to the test setup.
        var northStdIdx: Int?
        var southStdIdx: Int?
        for i in s.stores.indices {
            let st = s.stores[i]
            guard st.tier == .standard else { continue }
            if st.wing == .north && northStdIdx == nil { northStdIdx = i }
            if st.wing == .south && southStdIdx == nil { southStdIdx = i }
        }
        guard let northStdIdx, let southStdIdx else { return XCTFail() }
        s.stores[northStdIdx].threshold = testThreshold
        s.stores[southStdIdx].threshold = testThreshold
        s.stores[northStdIdx].hardship = 1   // baseline above 0 so decrement is observable
        s.stores[southStdIdx].hardship = 1

        // Trigger cascade on north wing.
        s.wingTrafficMultipliers[.north] = 0.75

        // Tick once. Disable the cascade hardship stagger so we isolate
        // the traffic-multiplier effect.
        s.pendingWingHardshipMonths = [.north: 0, .south: 0]
        s.anchorDepartedWings.insert(.north)   // suppresses future re-trigger

        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)

        // North (cascade wing): traffic seen < threshold*2.2 → hardship += 1
        // South (control): traffic seen >= threshold*2.2 → hardship -= 1
        XCTAssertGreaterThan(s.stores[northStdIdx].hardship, 1,
                             "cascade wing tenant's hardship increased under reduced effective traffic")
        XCTAssertLessThan(s.stores[southStdIdx].hardship, 1,
                          "control wing tenant's hardship decreased — traffic met threshold")
    }
}

// MARK: - Mall.wingEnvironmentState resolver

final class WingEnvironmentStateTests: XCTestCase {

    func testZeroOffsetReturnsMallWideState() {
        let s = StartingMall.initialState()
        let mallWide = EnvironmentState.from(s)
        XCTAssertEqual(Mall.wingEnvironmentState(for: .north, in: s), mallWide)
        XCTAssertEqual(Mall.wingEnvironmentState(for: .south, in: s), mallWide)
    }

    func testPositiveOffsetStepsTowardGhostMall() {
        var s = StartingMall.initialState()
        let base = EnvironmentState.from(s)   // should be .thriving in starting state
        XCTAssertEqual(base, .thriving)

        s.wingEnvOffsets[.north] = 1
        XCTAssertEqual(Mall.wingEnvironmentState(for: .north, in: s), .fading)

        s.wingEnvOffsets[.north] = 3
        XCTAssertEqual(Mall.wingEnvironmentState(for: .north, in: s), .dying)

        // Clamping: an offset past the end pins to ghostMall (the terminal state).
        s.wingEnvOffsets[.north] = 99
        XCTAssertEqual(Mall.wingEnvironmentState(for: .north, in: s), .ghostMall)
    }

    func testOpposingWingUnaffectedByOffset() {
        var s = StartingMall.initialState()
        s.wingEnvOffsets[.north] = 3
        XCTAssertEqual(Mall.wingEnvironmentState(for: .north, in: s), .dying)
        XCTAssertEqual(Mall.wingEnvironmentState(for: .south, in: s), .thriving,
                       "south wing offset is 0; renders at mall-wide state")
    }
}

// MARK: - Idempotency

final class AnchorCascadeIdempotencyTests: XCTestCase {

    // Guard: if something re-tenants an anchor slot and it re-closes, the
    // cascade must NOT re-fire on the same wing. anchorDepartedWings is
    // the flag; the cascade skip path is in TenantLifecycle.
    func testCascadeFiresOnceEvenOnRepeatedAnchorClosure() {
        var s = StartingMall.initialState()
        guard let anchorIdx = s.stores.firstIndex(where: { $0.tier == .anchor }) else {
            return XCTFail()
        }
        let anchorPos = s.stores[anchorIdx].position
        let wing = s.stores[anchorIdx].wing
        s = TenantLifecycle.vacateSlot(storeIndex: anchorIdx, state: s)

        let cascadeArtifactCountAfterFirst = s.artifacts.filter {
            $0.type == .stoppedEscalator || $0.type == .lostSignage
        }.count
        XCTAssertEqual(cascadeArtifactCountAfterFirst, 2)

        // Synthetic: re-tenant the slot with another anchor-tier tenant,
        // then close it. Current mechanics don't do this on their own;
        // this is a defensive test.
        s.stores[anchorIdx] = Store(
            id: s.stores[anchorIdx].id,
            name: "Impostor Anchor", tier: .anchor,
            rent: 4000, originalRent: 4000, rentMultiplier: 1.0,
            traffic: 260, threshold: 130, lease: 96,
            hardship: 0, closing: false, leaving: false,
            monthsOccupied: 12, monthsVacant: 0, promotionActive: false,
            position: anchorPos
        )
        s = TenantLifecycle.vacateSlot(storeIndex: anchorIdx, state: s)

        let cascadeArtifactCountAfterSecond = s.artifacts.filter {
            $0.type == .stoppedEscalator || $0.type == .lostSignage
        }.count
        XCTAssertEqual(cascadeArtifactCountAfterSecond, 2,
                       "cascade must not double-spawn on the same wing")
        XCTAssertTrue(s.anchorDepartedWings.contains(wing))
    }
}
