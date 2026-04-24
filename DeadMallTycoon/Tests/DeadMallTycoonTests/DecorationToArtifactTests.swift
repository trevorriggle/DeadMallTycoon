import XCTest
@testable import DeadMallTycoon

// v9 Prompt 3 coverage. Pin the decoration → artifact merge so future prompts
// can't silently regress the catalog parity or the starting seed.
//
// Checklist items (from the pre-execution plan):
//   1. Build + pre-existing tests green — enforced by the suite overall.
//   2. Starting mall seeds exactly the 5 period-appropriate artifacts.
//   3. aestheticMult formula logic + catalog parity for preserved types.
//   4. Decay cycle still works — covered by DecayTests.testAtLeastOneArtifactAdvancesOverAYear.
//   5. Janitorial halves decay — covered by DecayTests.testJanitorialHalvesDecayRate.
//   6. Disaster events still mutate artifact state — testBurstPipesAdvancesSouthSideArtifacts etc.
//   7. Force-evict still spawns boardedStorefront — covered by ArtifactSpawnTests.
//   8. Acquire tab functional — manual check + testPlacePutsArtifactOnCorridor.

// MARK: - Catalog parity with v8 DECORATION_TYPES

final class CatalogParityTests: XCTestCase {

    // v8 DECORATION_TYPES values, pinned exactly. The Prompt 3 rewrite must
    // not perturb these numbers for the six preserved types — breaking
    // catalog parity would change scoring on every pre-existing save.
    func testKugelBallParity() {
        let info = ArtifactCatalog.info(.kugelBall)
        XCTAssertEqual(info.baseMult, 0.15, accuracy: 0.0001)
        XCTAssertEqual(info.ruinMult, 0.30, accuracy: 0.0001)
        XCTAssertEqual(info.cost, 3500)
        XCTAssertEqual(info.repair, 800)
    }

    func testFountainParity() {
        let info = ArtifactCatalog.info(.fountain)
        XCTAssertEqual(info.baseMult, 0.10, accuracy: 0.0001)
        XCTAssertEqual(info.ruinMult, 0.25, accuracy: 0.0001)
        XCTAssertEqual(info.cost, 2500)
        XCTAssertEqual(info.repair, 600)
    }

    func testPlanterParity() {
        let info = ArtifactCatalog.info(.planter)
        XCTAssertEqual(info.baseMult, 0.03, accuracy: 0.0001)
        XCTAssertEqual(info.ruinMult, 0.08, accuracy: 0.0001)
        XCTAssertEqual(info.cost, 400)
        XCTAssertEqual(info.repair, 100)
    }

    func testNeonSignParity() {
        let info = ArtifactCatalog.info(.neonSign)
        XCTAssertEqual(info.baseMult, 0.08, accuracy: 0.0001)
        XCTAssertEqual(info.ruinMult, 0.20, accuracy: 0.0001)
        XCTAssertEqual(info.cost, 1200)
        XCTAssertEqual(info.repair, 300)
    }

    func testBenchParity() {
        let info = ArtifactCatalog.info(.bench)
        XCTAssertEqual(info.baseMult, 0.02, accuracy: 0.0001)
        XCTAssertEqual(info.ruinMult, 0.05, accuracy: 0.0001)
        XCTAssertEqual(info.cost, 600)
        XCTAssertEqual(info.repair, 150)
    }

    func testDirectoryBoardParity() {
        let info = ArtifactCatalog.info(.directoryBoard)
        XCTAssertEqual(info.baseMult, 0.05, accuracy: 0.0001)
        XCTAssertEqual(info.ruinMult, 0.15, accuracy: 0.0001)
        XCTAssertEqual(info.cost, 1500)
        XCTAssertEqual(info.repair, 400)
    }

    // Every ArtifactType must have a placeholder triggers pool so decay or
    // memory-weight consumers (Prompt 5) never hit an empty array.
    func testEveryTypeHasPlaceholderTriggers() {
        for type in ArtifactType.allCases {
            XCTAssertFalse(ArtifactCatalog.info(type).defaultTriggers.isEmpty,
                           "type \(type) must have default triggers")
        }
    }

    // Placeable list derived from catalog cost — Acquire tab depends on this.
    func testPlaceableTypesCountMatchesSpec() {
        // 26 placeable types expected per Prompt 3 plan:
        //   6 preserved + 2 seed-set new + 18 Prompt 3 roster = 26.
        // Ambient types (boardedStorefront, sealedEntrance, emptyFoodCourt,
        // custom) have cost == 0 and are filtered out.
        XCTAssertEqual(ArtifactCatalog.placeableTypes.count, 26)
    }

    func testAmbientTypesHaveZeroCost() {
        let ambient: [ArtifactType] = [
            .boardedStorefront, .sealedEntrance, .emptyFoodCourt, .custom,
        ]
        for t in ambient {
            XCTAssertEqual(ArtifactCatalog.info(t).cost, 0,
                           "\(t) should be cost 0 (ambient / event-spawned)")
        }
    }
}

// MARK: - Starting seed

final class StartingSeedTests: XCTestCase {

    // v9 Prompt 3 — the default mall has the five period-appropriate artifacts
    // pre-placed. Everything else is player-placeable.
    func testStartingMallSeedsExactlyFiveArtifacts() {
        let s = StartingMall.initialState()
        XCTAssertEqual(s.artifacts.count, 5)
        let types = Set(s.artifacts.map(\.type))
        XCTAssertEqual(types, Set([
            .kugelBall, .fountain, .directoryBoard,
            .skylight, .terrazzoFlooring,
        ]))
    }

    func testStartingArtifactsHavePositionsAndOrigins() {
        let s = StartingMall.initialState()
        for a in s.artifacts {
            XCTAssertNotNil(a.x, "seed artifacts must have a corridor x")
            XCTAssertNotNil(a.y, "seed artifacts must have a corridor y")
            if case .playerAction = a.origin { /* ok */ }
            else { XCTFail("seed origin should be .playerAction, got \(a.origin)") }
        }
    }

    // v8 starting mall had 10 decorations; v9 Prompt 3 intentionally reduces
    // to 5. The aestheticMult will therefore change — document the new
    // expected starting multiplier so later prompts don't perturb it.
    func testStartingAestheticMultIsPinnedValue() {
        let s = StartingMall.initialState()
        let mult = Economy.aestheticMult(s)
        // Starting seed: kugel(c=2)+fountain(c=1)+directory(c=3)+skylight(c=1)+terrazzo(c=2)
        //   kugel:     0.15 * (1 + 0.2*2) = 0.21
        //   fountain:  0.10 * (1 + 0.2*1) = 0.12
        //   directory: 0.05 * (1 + 0.2*3) = 0.08
        //   skylight:  0.12 * (1 + 0.2*1) = 0.144
        //   terrazzo:  0.08 * (1 + 0.2*2) = 0.112
        //   decSum = 0.666; decMult = 1.666
        //   vacMult (2 vac / 18 total): 1 + (2/18)*1.2 = 1.1333
        //   raw = 1.666 * 1.1333 = 1.888... → round to 0.1 = 1.9
        XCTAssertEqual(mult, 1.9, accuracy: 0.05)
    }
}

// MARK: - aestheticMult formula parity (logic unchanged, source swapped)

final class AestheticMultFormulaTests: XCTestCase {

    // Pin: for the six preserved types, contribution is the v8 formula
    // `condition >= 4 ? ruinMult : baseMult * (1 + 0.2 * condition)`.
    func testPreservedTypeContributionMatchesV8Formula() {
        var s = GameState()
        s.stores = StartingMall.buildStores()
        // Only one artifact: a fountain at condition 2.
        s.artifacts = [ArtifactFactory.make(
            id: 1, type: .fountain, name: "Fountain",
            origin: .playerAction("test"),
            yearCreated: 1982,
            x: 100, y: 250)]
        s.artifacts[0].condition = 2

        // Expected contribution = 0.10 * (1 + 0.2*2) = 0.14
        // decMult = 1 + 0.14 = 1.14
        // vacMult: 2 vacant of 18 total (starting seed) = 1 + (2/18)*1.2 = 1.1333
        // raw = 1.14 * 1.1333 = 1.292 → rounded to 0.1 = 1.3
        XCTAssertEqual(Economy.aestheticMult(s), 1.3, accuracy: 0.05)
    }

    // Ambient types (catalog cost == 0) contribute 0 to aestheticMult in Prompt 3.
    // Scoring role lands later via memoryWeight (Prompt 5).
    func testAmbientArtifactsDontAffectAestheticMult() {
        var s = GameState()
        s.stores = StartingMall.buildStores()
        let baseline = Economy.aestheticMult(s)

        s.artifacts = [
            ArtifactFactory.make(id: 1, type: .boardedStorefront, name: "Old Store",
                                 origin: .tenant(name: "Old Store"),
                                 yearCreated: 1982, storeSlotId: 1),
            ArtifactFactory.make(id: 2, type: .sealedEntrance, name: "Sealed",
                                 origin: .event(name: "test"), yearCreated: 1982),
        ]
        XCTAssertEqual(Economy.aestheticMult(s), baseline,
                       "ambient artifacts must not contribute to aestheticMult")
    }
}

// MARK: - ArtifactActions.place

final class ArtifactPlacementTests: XCTestCase {

    func testPlaceDeductsCashAndAppendsArtifact() {
        var s = StartingMall.initialState()
        s.cash = 5000
        let before = s.artifacts.count

        s = ArtifactActions.place(type: .photoBooth,
                                  at: (x: 300, y: 250), s)

        XCTAssertEqual(s.artifacts.count, before + 1)
        XCTAssertEqual(s.cash, 5000 - ArtifactCatalog.info(.photoBooth).cost)
        let placed = s.artifacts.last!
        XCTAssertEqual(placed.type, .photoBooth)
        XCTAssertNotNil(placed.x)
        XCTAssertNotNil(placed.y)
        XCTAssertEqual(placed.condition, 0)
        XCTAssertFalse(placed.hazard)
    }

    func testPlaceInsideStorefrontRejects() {
        // v9 Prompt 22 — placement gate replaced the old y-range check
        // with an AABB overlap against every Store.position. A photo
        // booth centered at (300, 100) spans roughly x:285..315 y:76..124
        // which sits inside the north-standard row (x:200..1000, y:0..90)
        // → overlap → placement rejected.
        var s = StartingMall.initialState()
        s.cash = 5000
        let before = s.artifacts.count

        s = ArtifactActions.place(type: .photoBooth,
                                  at: (x: 300, y: 100), s)
        XCTAssertEqual(s.artifacts.count, before)
        XCTAssertEqual(s.cash, 5000)
    }

    func testPlaceInsideAnchorColumnRejects() {
        // v9 Prompt 22 — anchor rects (x:0..200 north, x:1000..1200
        // south, both y:200..1200) are gated like any other storefront.
        // A photo booth at (100, 600) would sit inside Halvorsen; must
        // be rejected even though the old y-range check would've let it
        // through.
        var s = StartingMall.initialState()
        s.cash = 5000
        let before = s.artifacts.count

        s = ArtifactActions.place(type: .photoBooth,
                                  at: (x: 100, y: 600), s)
        XCTAssertEqual(s.artifacts.count, before)
        XCTAssertEqual(s.cash, 5000)
    }

    func testPlaceInUpperAccessCorridorAccepted() {
        // v9 Prompt 22 — the strip between the north storefront row
        // (y:0..90) and the anchor tops (y:200) is walkable corridor
        // and must be placeable. The old y<300 gate wrongly blocked
        // it; the new AABB check lets it through.
        var s = StartingMall.initialState()
        s.cash = 5000
        let before = s.artifacts.count

        // photoBooth is 30x48; at x:500 y:150 its rect is x:485..515
        // y:126..174 — no overlap with any store.
        s = ArtifactActions.place(type: .photoBooth,
                                  at: (x: 500, y: 150), s)
        XCTAssertEqual(s.artifacts.count, before + 1,
                       "placement near the north access corridor succeeds")
    }

    func testPlaceOutsideWorldBoundsRejects() {
        // v9 Prompt 22 — bounding box must sit inside the world. A
        // center at y:-5 pushes the rect's top below 0.
        var s = StartingMall.initialState()
        s.cash = 5000
        let before = s.artifacts.count

        s = ArtifactActions.place(type: .photoBooth,
                                  at: (x: 500, y: -5), s)
        XCTAssertEqual(s.artifacts.count, before)
    }

    func testPlaceWithInsufficientCashRejects() {
        var s = StartingMall.initialState()
        s.cash = 50   // less than any placeable type's cost
        let before = s.artifacts.count

        s = ArtifactActions.place(type: .photoBooth,
                                  at: (x: 300, y: 250), s)
        XCTAssertEqual(s.artifacts.count, before)
        XCTAssertEqual(s.cash, 50)
    }

    func testPlaceAmbientTypeIsRejected() {
        var s = StartingMall.initialState()
        s.cash = 5000
        let before = s.artifacts.count

        // Ambient types have cost 0 and shouldn't be player-placeable.
        s = ArtifactActions.place(type: .boardedStorefront,
                                  at: (x: 300, y: 250), s)
        XCTAssertEqual(s.artifacts.count, before)
    }

    func testRepairClampsConditionAndClearsHazard() {
        var s = StartingMall.initialState()
        s.cash = 5000
        // Grab the seeded directory (condition 3).
        guard let idx = s.artifacts.firstIndex(where: { $0.type == .directoryBoard }) else {
            return XCTFail("expected a seeded directory board")
        }
        s.artifacts[idx].condition = 4
        s.artifacts[idx].hazard = true

        s = ArtifactActions.repair(artifactId: s.artifacts[idx].id, s)

        let after = s.artifacts.first { $0.id == s.artifacts[idx].id }!
        XCTAssertEqual(after.condition, 2)   // max(0, 4-2)
        XCTAssertFalse(after.hazard)
    }

    func testRemoveDropsArtifact() {
        var s = StartingMall.initialState()
        let id = s.artifacts[0].id
        s = ArtifactActions.remove(artifactId: id, s)
        XCTAssertFalse(s.artifacts.contains { $0.id == id })
    }
}

// MARK: - Disaster events still mutate artifact state

final class DisasterEventArtifactMutationTests: XCTestCase {

    func testBurstPipesAdvancesSouthSideArtifacts() {
        var s = StartingMall.initialState()
        // Place a test artifact south of y=300 at condition 0.
        s.cash = 10_000
        s = ArtifactActions.place(type: .fountain,
                                  at: (x: 500, y: 310), s)
        let placedId = s.artifacts.last!.id
        let before = s.artifacts.first { $0.id == placedId }!.condition

        let ev = FlavorEvent(
            kind: .burstPipes(repairCost: 4000),
            name: "Burst Pipes", description: "test",
            acceptLabel: "Repair", declineLabel: "Leave It"
        )
        var rng = SeededGenerator(seed: 1)
        s = EventDeck.apply(ev, choice: .decline, state: s, rng: &rng)

        let after = s.artifacts.first { $0.id == placedId }!.condition
        XCTAssertEqual(after, before + 1,
                       "south-side artifact condition should advance on burst-pipes decline")
    }

    func testCityInspectionTagsTwoArtifactsAsHazard() {
        var s = StartingMall.initialState()
        let ev = FlavorEvent(
            kind: .cityInspection(cooperateCost: 2500),
            name: "City Inspection", description: "test",
            acceptLabel: "Cooperate", declineLabel: "Stonewall"
        )
        var rng = SeededGenerator(seed: 7)
        let beforeHazards = s.artifacts.filter(\.hazard).count
        s = EventDeck.apply(ev, choice: .decline, state: s, rng: &rng)
        let afterHazards = s.artifacts.filter(\.hazard).count

        XCTAssertEqual(afterHazards - beforeHazards, 2,
                       "city-inspection decline must tag exactly 2 artifacts hazard")
    }
}
