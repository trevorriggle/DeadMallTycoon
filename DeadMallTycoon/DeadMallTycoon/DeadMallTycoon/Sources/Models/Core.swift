import Foundation
import CoreGraphics

// Simple enums and primitive types shared across the game.
// Ported from v8 string constants in the G object and inline.

enum MallState: String, Codable, CaseIterable {
    case thriving, fading, struggling, dying, dead
}                                                     // v8: getMallState() return values

enum ThreatBand {
    case stable, uneasy, risky, critical
    var displayName: String {
        switch self {
        case .stable: return "Stable"
        case .uneasy: return "Uneasy"
        case .risky: return "Risky"
        case .critical: return "Critical"
        }
    }
}                                                     // v8: getThreatBand()

enum Wing: String, Codable, CaseIterable, Hashable {
    case north, south
}

// v9 Prompt 6.5 — per-corner entrance identity.
//
// The iPad port relocated the two mid-wall entrances to four corner doors
// (NW/NE/SW/SE). Each corner is independently sealable; wings continue to
// be north-row / south-row and are NOT redefined by corner.
//
// Corner → wing mapping is fixed: NW/NE → .north, SW/SE → .south. A wing
// closure hides both of its corners' doors; an entrance seal takes out a
// single corner without affecting the other on the same wing.
enum EntranceCorner: String, Codable, CaseIterable, Hashable {
    case nw, ne, sw, se

    var wing: Wing {
        switch self {
        case .nw, .ne: return .north
        case .sw, .se: return .south
        }
    }
}

// v9 Prompt 17 — `.specialty` added as a sixth tier for professional-
// service tenants that don't need mall foot traffic (podiatrists,
// tax prep, hearing aid clinics, business libraries). Specialty
// tenants are traffic-closure-immune by convention and pay mid-range
// rent ($2,500-3,500/mo) on long leases (3-5 years). They become the
// mechanical answer to "the one tenant that remains for 14 years."
enum StoreTier: String, Codable {
    case anchor, standard, kiosk, sketchy, specialty, vacant
}

enum VisitorType: String, Codable {
    case teen, adult, elder, kid
}

enum VisitorState: String, Codable {
    case entering, wandering, leaving
}

enum Speed: Int, Codable, CaseIterable {
    case paused = 0, x1 = 1, x2 = 2, x4 = 3, x8 = 4
    // v8: setSpd() — [null, 4000, 2000, 1000, 500]
    // v9 patch — doubled the base tick to 8s/month at 1x. Speed ratios are
    // preserved (each step halves the previous). The slowdown is to let
    // ambient life (visitor walking, thoughts firing) read as sustained
    // atmosphere rather than a fast-forward montage. Memory weight per
    // game-month is held constant via the corresponding halving of
    // ThoughtTuning.memoryWeightBaseIncrement (see Thought.swift).
    var tickIntervalMs: Int? {
        switch self {
        case .paused: return nil
        case .x1: return 8000
        case .x2: return 4000
        case .x4: return 2000
        case .x8: return 1000
        }
    }
}

enum Tab: String, Codable {
    case mall, operations, tenants, promotions, revenue
}

enum Severity: String, Codable {
    case watch, warn, danger
    var sortOrder: Int {
        switch self {
        case .danger: return 0
        case .warn: return 1
        case .watch: return 2
        }
    }
}                                                     // v8: addWarning() severity keys

// v8: DECORATION_TYPES keys — moved to ArtifactType in Artifact.swift.
// v9 Prompt 3 — DecorationKind enum deleted; unified taxonomy is ArtifactType.

enum EventChoice {
    case accept, decline
}

// v8: STORE_POSITIONS entry shape
struct StorePosition: Equatable, Codable {
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    let wing: Wing
}

// v8: v.target
struct VisitorTarget: Equatable, Codable {
    var x: Double
    var y: Double
    var storeId: Int?
}

// Fixed-capacity history buffer for the v9 score sparkline.
struct RingBuffer<T: Equatable>: Equatable {
    let capacity: Int
    private(set) var values: [T] = []

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    mutating func append(_ value: T) {
        values.append(value)
        if values.count > capacity {
            values.removeFirst()
        }
    }

    var count: Int { values.count }
    var isEmpty: Bool { values.isEmpty }
}

enum GameConstants {
    static let debtCeiling = 25_000                   // v8: DEBT_CEIL
    static let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    static let startingCash = 3_500
    static let startingYear = 1982
    static let worldWidth: Double = 1200              // v8: stage width
    // v9 patch — was 520. Grown to 1400 so the world's aspect (1200/1400 ≈
    // 0.86) matches an iPad portrait's available scene area (~834/980 ≈
    // 0.85). Storefronts repositioned to y:0..90 (north) and y:1310..1400
    // (south) sit flush against the HUD borders with no letterbox bands.
    // Anchors stretched to fill the new corridor proportionally so the
    // H-shape walkable geometry is preserved.
    static let worldHeight: Double = 1400
    // v9 patch — corridor band (between the two storefront rows) stretches
    // with the world. Anchors flank this corridor; access corridors live
    // just inside (110pt strips above/below the anchor band).
    static let corridorTop: Double = 90
    static let corridorBottom: Double = 1310
}
