import Foundation

// v8: STORE_POSITIONS, STARTING_STORES, STARTING_DECORATIONS + initial G hydration.
enum StartingMall {

    // Anchor end-caps (Sears west, JCPenney east) are the terminal anchors
    // of the mall. 200pt wide (2× a standard storefront).
    // Total slot count: 18 (9 per wing, each wing = 1 anchor + 8 standards).
    //
    // v8 parity note: v8 treated Sears/JCP as standard-sized slots with higher rent.
    // The iPad port diverges here — anchors are architecturally distinct.
    //
    // v9 Prompt 6.5 — anchors relocated. Previously full-scene-height (y 10..510)
    // bookends that occupied the corner real estate. Now corridor-height
    // flanks (y 110..410, h:300) so the four corner blocks are free for
    // the new NW/NE/SW/SE entrance doors. Width and wing assignments
    // preserved; anchor-tier detection by position.w >= 180 survives.
    static let positions: [StorePosition] = [
        // North anchor (Sears) — west corridor flank, between the corner doors.
        // v9 Prompt 6.5 — was `y:10, h:500` full-height bookend.
        StorePosition(x:    0, y: 110, w: 200, h: 300, wing: .north),
        // North standards — 8 storefronts butted up across x 200..1000.
        StorePosition(x:  200, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  300, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  400, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  500, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  600, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  700, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  800, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  900, y:  20, w: 100, h: 90, wing: .north),
        // South standards — 8 storefronts butted up across x 200..1000.
        StorePosition(x:  200, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  300, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  400, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  500, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  600, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  700, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  800, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  900, y: 410, w: 100, h: 90, wing: .south),
        // South anchor (JCPenney) — east corridor flank, between the corner doors.
        // v9 Prompt 6.5 — was `y:10, h:500` full-height bookend.
        StorePosition(x: 1000, y: 110, w: 200, h: 300, wing: .south),
    ]

    // v8: STARTING_STORES
    // Paired with positions by index. The iPad port drops 2 seeds vs v8 (Lids, Things Remembered)
    // to land on 18 slots while preserving the 2 starting vacant slots that seed the early
    // tenant-offer decision flow.
    private struct StoreSeed {
        let name: String
        let tier: StoreTier
        let rent: Int
        let traffic: Int
        let threshold: Int
        let lease: Int
    }

    private static let storeSeeds: [StoreSeed] = [
        StoreSeed(name: "Sears",              tier: .anchor,   rent: 4500, traffic: 300, threshold: 150, lease: 96),
        StoreSeed(name: "Sam Goody",          tier: .standard, rent: 1200, traffic:  70, threshold:  40, lease: 36),
        StoreSeed(name: "Waldenbooks",        tier: .standard, rent: 1000, traffic:  50, threshold:  28, lease: 30),
        StoreSeed(name: "Foot Locker",        tier: .standard, rent: 1400, traffic:  80, threshold:  45, lease: 36),
        StoreSeed(name: "Hot Topic",          tier: .standard, rent:  900, traffic:  60, threshold:  35, lease: 24),
        StoreSeed(name: "Claire's",           tier: .standard, rent:  700, traffic:  45, threshold:  22, lease: 30),
        StoreSeed(name: "Radio Shack",        tier: .standard, rent:  800, traffic:  50, threshold:  28, lease: 36),
        StoreSeed(name: "Kay Jewelers",       tier: .standard, rent: 1500, traffic:  40, threshold:  18, lease: 48),
        StoreSeed(name: "Spencer's",          tier: .standard, rent:  800, traffic:  55, threshold:  30, lease: 24),
        StoreSeed(name: "B. Dalton",          tier: .standard, rent:  900, traffic:  45, threshold:  24, lease: 30),
        StoreSeed(name: "Cinnabon",           tier: .kiosk,    rent:  450, traffic:  40, threshold:  22, lease: 24),
        StoreSeed(name: "Orange Julius",      tier: .kiosk,    rent:  400, traffic:  35, threshold:  20, lease: 18),
        StoreSeed(name: "Sunglass Hut",       tier: .kiosk,    rent:  300, traffic:  20, threshold:  12, lease: 24),
        StoreSeed(name: "",                   tier: .vacant,   rent:    0, traffic:   0, threshold:   0, lease:  0),
        StoreSeed(name: "",                   tier: .vacant,   rent:    0, traffic:   0, threshold:   0, lease:  0),
        StoreSeed(name: "Auntie Anne's",      tier: .kiosk,    rent:  400, traffic:  40, threshold:  20, lease: 18),
        StoreSeed(name: "Vape Shop",          tier: .sketchy,  rent:  200, traffic:   8, threshold:   0, lease: 18),
        StoreSeed(name: "JCPenney",           tier: .anchor,   rent: 4000, traffic: 260, threshold: 130, lease: 96),
    ]

    // v8: STARTING_DECORATIONS — 10 seed items (2× fountain, 2× neon, 2× bench,
    // 2× plant, kugel, directory).
    // v9 Prompt 3 — starting seed reduced to the five period-appropriate
    // landmark artifacts per the spec: kugel ball, fountain, directory board,
    // skylight, terrazzo flooring. The reduction is intentional — the default
    // mall reads "empty and monumental" rather than "already decorated".
    // Everything else is player-placeable via the Acquire tab.
    private struct ArtifactSeed {
        let type: ArtifactType
        let x: Double
        let y: Double
        let condition: Int
        let working: Bool
        let hazard: Bool
    }

    private static let artifactSeeds: [ArtifactSeed] = [
        ArtifactSeed(type: .kugelBall,        x: 585, y: 245, condition: 2, working: true, hazard: false),
        ArtifactSeed(type: .fountain,         x: 275, y: 235, condition: 1, working: true, hazard: false),
        ArtifactSeed(type: .directoryBoard,   x: 650, y: 220, condition: 3, working: true, hazard: false),
        ArtifactSeed(type: .skylight,         x: 450, y: 210, condition: 1, working: true, hazard: false),
        ArtifactSeed(type: .terrazzoFlooring, x: 800, y: 290, condition: 2, working: true, hazard: false),
    ]

    // v8: initStores()
    static func buildStores() -> [Store] {
        zip(storeSeeds, positions).enumerated().map { idx, pair in
            let seed = pair.0
            let pos = pair.1
            return Store(
                id: idx,
                name: seed.name,
                tier: seed.tier,
                rent: seed.rent,
                originalRent: seed.rent,
                rentMultiplier: 1.0,
                traffic: seed.traffic,
                threshold: seed.threshold,
                lease: seed.lease,
                hardship: 0,
                closing: false, leaving: false,
                monthsOccupied: 0, monthsVacant: 0,
                promotionActive: false,
                position: pos
            )
        }
    }

    // v8: initDecorations()
    // v9 Prompt 3 — renamed to buildStartingArtifacts; produces Artifact
    // instances in the unified model. Condition + working + hazard values
    // carried over from the old seed table where applicable.
    static func buildStartingArtifacts() -> [Artifact] {
        artifactSeeds.enumerated().map { idx, seed in
            var a = ArtifactFactory.make(
                id: idx,
                type: seed.type,
                name: ArtifactCatalog.info(seed.type).name,
                origin: .playerAction("starting seed"),
                yearCreated: GameConstants.startingYear,
                x: seed.x, y: seed.y,
                working: seed.working,
                hazard: seed.hazard
            )
            a.condition = seed.condition
            return a
        }
    }

    // v8: startGame() initial state
    // v9 Prompt 3 — seeds state.artifacts instead of the deleted state.decorations.
    static func initialState() -> GameState {
        var s = GameState()
        s.stores = buildStores()
        s.artifacts = buildStartingArtifacts()
        s.started = true
        s.pendingLawsuitMonth = 4
        return s
    }
}
