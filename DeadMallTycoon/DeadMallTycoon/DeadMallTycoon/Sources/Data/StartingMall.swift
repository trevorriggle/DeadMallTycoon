import Foundation

// v8: STORE_POSITIONS, STARTING_STORES, STARTING_DECORATIONS + initial G hydration.
enum StartingMall {

    // Anchor end-caps (Halvorsen west, Pemberton east) are the terminal anchors
    // of the mall. 200pt wide (2× a standard storefront).
    // Total slot count: 18 (9 per wing, each wing = 1 anchor + 8 standards).
    //
    // v8 parity note: v8 treated Halvorsen/JCP as standard-sized slots with higher rent.
    // The iPad port diverges here — anchors are architecturally distinct.
    //
    // v9 Prompt 6.5 — anchors relocated from full-scene-height bookends to
    // corridor-side flanks; corner blocks freed for NW/NE/SW/SE entrance doors.
    //
    // v9 patch (worldHeight 520→1400) — geometry stretched so storefronts
    // sit flush against the iPad screen's HUD borders. Storefronts moved to
    // y:0 (north row) and y:1310 (south row). Anchors stretched to h:1000
    // (y:200..1200) to fill the now-much-taller corridor while preserving
    // the H-shape walkable layout (110pt access corridors above/below).
    // Width and wing assignments unchanged; anchor-tier detection by
    // position.w >= 180 survives.
    static let positions: [StorePosition] = [
        // v9 patch — geometry stretched for full-screen layout (worldHeight 1400).
        // Storefronts moved flush to top (y:0) and bottom (y:1310). Anchors
        // stretched to fill the corridor (y:200..1200, h:1000) so the H-shape
        // walkable geometry stays proportional in the taller world.
        // North anchor (Halvorsen) — west corridor flank.
        StorePosition(x:    0, y: 200, w: 200, h: 1000, wing: .north),
        // North standards — 8 storefronts butted up across x 200..1000, flush top.
        StorePosition(x:  200, y:   0, w: 100, h: 90, wing: .north),
        StorePosition(x:  300, y:   0, w: 100, h: 90, wing: .north),
        StorePosition(x:  400, y:   0, w: 100, h: 90, wing: .north),
        StorePosition(x:  500, y:   0, w: 100, h: 90, wing: .north),
        StorePosition(x:  600, y:   0, w: 100, h: 90, wing: .north),
        StorePosition(x:  700, y:   0, w: 100, h: 90, wing: .north),
        StorePosition(x:  800, y:   0, w: 100, h: 90, wing: .north),
        StorePosition(x:  900, y:   0, w: 100, h: 90, wing: .north),
        // South standards — 8 storefronts butted up across x 200..1000, flush bottom.
        StorePosition(x:  200, y: 1310, w: 100, h: 90, wing: .south),
        StorePosition(x:  300, y: 1310, w: 100, h: 90, wing: .south),
        StorePosition(x:  400, y: 1310, w: 100, h: 90, wing: .south),
        StorePosition(x:  500, y: 1310, w: 100, h: 90, wing: .south),
        StorePosition(x:  600, y: 1310, w: 100, h: 90, wing: .south),
        StorePosition(x:  700, y: 1310, w: 100, h: 90, wing: .south),
        StorePosition(x:  800, y: 1310, w: 100, h: 90, wing: .south),
        StorePosition(x:  900, y: 1310, w: 100, h: 90, wing: .south),
        // South anchor (Pemberton) — east corridor flank.
        StorePosition(x: 1000, y: 200, w: 200, h: 1000, wing: .south),
    ]

    // v8: STARTING_STORES
    // Paired with positions by index. The iPad port drops 2 seeds vs v8 (two
    // kiosk slots) to land on 18 slots while preserving the 2 starting vacant
    // slots that seed the early tenant-offer decision flow.
    private struct StoreSeed {
        let name: String
        let tier: StoreTier
        let rent: Int
        let traffic: Int
        let threshold: Int
        let lease: Int
        // v9 Prompt 17 — flagged seeds become Stores with
        // immuneToTrafficClosure = true. Used for the kiosk-tier
        // "quirky holdouts" (Auntie Rae's is the starting mall's one
        // such entry — ENDGAME.md's "pretzel kiosk for 14 years").
        var immune: Bool = false
    }

    private static let storeSeeds: [StoreSeed] = [
        StoreSeed(name: "Halvorsen",              tier: .anchor,   rent: 4500, traffic: 300, threshold: 150, lease: 96),
        StoreSeed(name: "Ricky's Records",          tier: .standard, rent: 1200, traffic:  70, threshold:  40, lease: 36),
        StoreSeed(name: "Brinkerhoff Books",        tier: .standard, rent: 1000, traffic:  50, threshold:  28, lease: 30),
        StoreSeed(name: "Sole Center",        tier: .standard, rent: 1400, traffic:  80, threshold:  45, lease: 36),
        StoreSeed(name: "Razor & Rose",          tier: .standard, rent:  900, traffic:  60, threshold:  35, lease: 24),
        StoreSeed(name: "Lulu & Lace",           tier: .standard, rent:  700, traffic:  45, threshold:  22, lease: 30),
        StoreSeed(name: "Signal Shack",        tier: .standard, rent:  800, traffic:  50, threshold:  28, lease: 36),
        StoreSeed(name: "Bell & Thornton",       tier: .standard, rent: 1500, traffic:  40, threshold:  18, lease: 48),
        StoreSeed(name: "Switchblade Novelty",          tier: .standard, rent:  800, traffic:  55, threshold:  30, lease: 24),
        StoreSeed(name: "Beckett Books",          tier: .standard, rent:  900, traffic:  45, threshold:  24, lease: 30),
        StoreSeed(name: "Cinna-Swirl",           tier: .kiosk,    rent:  450, traffic:  40, threshold:  22, lease: 24),
        StoreSeed(name: "Julius & Co",      tier: .kiosk,    rent:  400, traffic:  35, threshold:  20, lease: 18),
        StoreSeed(name: "Shadecraft",       tier: .kiosk,    rent:  300, traffic:  20, threshold:  12, lease: 24),
        StoreSeed(name: "",                   tier: .vacant,   rent:    0, traffic:   0, threshold:   0, lease:  0),
        StoreSeed(name: "",                   tier: .vacant,   rent:    0, traffic:   0, threshold:   0, lease:  0),
        // v9 Prompt 17 — Auntie Rae's flagged as a quirky holdout:
        // immuneToTrafficClosure=true. Mechanically, this is the
        // "pretzel kiosk that survived 14 years" from ENDGAME.md.
        StoreSeed(name: "Auntie Rae's",      tier: .kiosk,    rent:  400, traffic:  40, threshold:  20, lease: 36,
                  immune: true),
        StoreSeed(name: "Vape Shop",          tier: .sketchy,  rent:  200, traffic:   8, threshold:   0, lease: 18),
        StoreSeed(name: "Pemberton",           tier: .anchor,   rent: 4000, traffic: 260, threshold: 130, lease: 96),
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

    // v9 patch — y values updated for stretched world (worldHeight 1400).
    // Corridor center is around y:700; spread artifacts across the upper-
    // mid corridor band (y:500..900) so they read as central landmarks
    // rather than crammed near a single edge.
    private static let artifactSeeds: [ArtifactSeed] = [
        ArtifactSeed(type: .kugelBall,        x: 585, y: 700, condition: 2, working: true, hazard: false),
        ArtifactSeed(type: .fountain,         x: 275, y: 660, condition: 1, working: true, hazard: false),
        ArtifactSeed(type: .directoryBoard,   x: 650, y: 580, condition: 3, working: true, hazard: false),
        ArtifactSeed(type: .skylight,         x: 450, y: 500, condition: 1, working: true, hazard: false),
        ArtifactSeed(type: .terrazzoFlooring, x: 800, y: 820, condition: 2, working: true, hazard: false),
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
                position: pos,
                immuneToTrafficClosure: seed.immune
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
