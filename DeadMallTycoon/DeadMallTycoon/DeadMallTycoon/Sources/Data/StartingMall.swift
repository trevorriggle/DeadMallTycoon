import Foundation

// v8: STORE_POSITIONS, STARTING_STORES, STARTING_DECORATIONS + initial G hydration.
enum StartingMall {

    // v8: STORE_POSITIONS — 20 slots, 10 north + 10 south, fixed layout.
    static let positions: [StorePosition] = [
        StorePosition(x:   20, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  128, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  236, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  344, y:  20, w: 140, h: 90, wing: .north),
        StorePosition(x:  492, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  600, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  708, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  816, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x:  924, y:  20, w: 100, h: 90, wing: .north),
        StorePosition(x: 1032, y:  20, w: 130, h: 90, wing: .north),
        StorePosition(x:   20, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  128, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  236, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  344, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  452, y: 410, w: 140, h: 90, wing: .south),
        StorePosition(x:  600, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  708, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  816, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x:  924, y: 410, w: 100, h: 90, wing: .south),
        StorePosition(x: 1032, y: 410, w: 130, h: 90, wing: .south),
    ]

    // v8: STARTING_STORES
    // Paired with positions by index; entries with tier:.vacant represent STARTING_STORES' two vacant slots.
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
        StoreSeed(name: "JCPenney",           tier: .anchor,   rent: 4000, traffic: 260, threshold: 130, lease: 96),
        StoreSeed(name: "B. Dalton",          tier: .standard, rent:  900, traffic:  45, threshold:  24, lease: 30),
        StoreSeed(name: "Cinnabon",           tier: .kiosk,    rent:  450, traffic:  40, threshold:  22, lease: 24),
        StoreSeed(name: "Orange Julius",      tier: .kiosk,    rent:  400, traffic:  35, threshold:  20, lease: 18),
        StoreSeed(name: "Sunglass Hut",       tier: .kiosk,    rent:  300, traffic:  20, threshold:  12, lease: 24),
        StoreSeed(name: "Lids",               tier: .kiosk,    rent:  250, traffic:  18, threshold:   8, lease: 18),
        StoreSeed(name: "Things Remembered",  tier: .kiosk,    rent:  300, traffic:  20, threshold:  10, lease: 18),
        StoreSeed(name: "",                   tier: .vacant,   rent:    0, traffic:   0, threshold:   0, lease:  0),
        StoreSeed(name: "",                   tier: .vacant,   rent:    0, traffic:   0, threshold:   0, lease:  0),
        StoreSeed(name: "Auntie Anne's",      tier: .kiosk,    rent:  400, traffic:  40, threshold:  20, lease: 18),
        StoreSeed(name: "Vape Shop",          tier: .sketchy,  rent:  200, traffic:   8, threshold:   0, lease: 18),
    ]

    // v8: STARTING_DECORATIONS
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
        DecorationSeed(kind: .neon,      x:   90, y: 200, condition: 2, working: true,  hazard: false),
        DecorationSeed(kind: .neon,      x: 1080, y: 200, condition: 1, working: true,  hazard: false),
        DecorationSeed(kind: .bench,     x:  460, y: 260, condition: 1, working: true,  hazard: false),
        DecorationSeed(kind: .bench,     x:  710, y: 260, condition: 0, working: true,  hazard: false),
        DecorationSeed(kind: .plant,     x:  160, y: 280, condition: 2, working: true,  hazard: false),
        DecorationSeed(kind: .plant,     x: 1010, y: 280, condition: 1, working: true,  hazard: false),
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
