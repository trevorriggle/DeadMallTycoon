import Foundation

// v8: STORE_POSITIONS, STARTING_STORES, STARTING_DECORATIONS + initial G hydration.
enum StartingMall {

    // Anchor end-caps (Sears west, JCPenney east) are full scene-height structures
    // that visually terminate the corridor. 200pt wide (2× a standard storefront),
    // spanning y 10..510 so they read as department stores, not inline storefronts.
    // Total slot count: 18 (9 per wing, each wing = 1 anchor + 8 standards).
    //
    // v8 parity note: v8 treated Sears/JCP as standard-sized slots with higher rent.
    // The iPad port diverges here — anchors are architecturally distinct.
    static let positions: [StorePosition] = [
        // North anchor (Sears) — full-height west end-cap.
        StorePosition(x:    0, y:  10, w: 200, h: 500, wing: .north),
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
        // South anchor (JCPenney) — full-height east end-cap.
        StorePosition(x: 1000, y:  10, w: 200, h: 500, wing: .south),
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

    // v8: STARTING_DECORATIONS
    // Decorations that previously sat at x<200 or x>1000 are moved inward since
    // those x ranges are now occupied by the anchor end-caps.
    private struct DecorationSeed {
        let kind: DecorationKind
        let x: Double
        let y: Double
        let condition: Int
        let working: Bool
        let hazard: Bool
    }

    private static let decorationSeeds: [DecorationSeed] = [
        DecorationSeed(kind: .kugel,     x:  585, y: 245, condition: 2, working: true,  hazard: false),
        DecorationSeed(kind: .fountain,  x:  275, y: 235, condition: 1, working: true,  hazard: false),
        DecorationSeed(kind: .fountain,  x:  875, y: 235, condition: 3, working: false, hazard: true),
        DecorationSeed(kind: .neon,      x:  220, y: 200, condition: 2, working: true,  hazard: false),  // was x=90 (inside Sears)
        DecorationSeed(kind: .neon,      x:  960, y: 200, condition: 1, working: true,  hazard: false),  // was x=1080 (inside JCP)
        DecorationSeed(kind: .bench,     x:  460, y: 260, condition: 1, working: true,  hazard: false),
        DecorationSeed(kind: .bench,     x:  710, y: 260, condition: 0, working: true,  hazard: false),
        DecorationSeed(kind: .plant,     x:  250, y: 280, condition: 2, working: true,  hazard: false),  // was x=160 (inside Sears)
        DecorationSeed(kind: .plant,     x:  930, y: 280, condition: 1, working: true,  hazard: false),  // was x=1010 (inside JCP)
        DecorationSeed(kind: .directory, x:  650, y: 220, condition: 3, working: true,  hazard: false),
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
    static func buildDecorations() -> [Decoration] {
        decorationSeeds.enumerated().map { idx, seed in
            Decoration(
                id: idx, kind: seed.kind,
                x: seed.x, y: seed.y,
                condition: seed.condition,
                working: seed.working,
                hazard: seed.hazard,
                monthsAtCondition: 0
            )
        }
    }

    // v8: startGame() initial state
    static func initialState() -> GameState {
        var s = GameState()
        s.stores = buildStores()
        s.decorations = buildDecorations()
        s.started = true
        s.pendingLawsuitMonth = 4
        return s
    }
}
