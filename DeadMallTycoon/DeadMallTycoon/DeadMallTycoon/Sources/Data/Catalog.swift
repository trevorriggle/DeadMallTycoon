import Foundation
import CoreGraphics

// v8: DECORATION_TYPES entry shape — migrated to ArtifactTypeInfo.
// v9 Prompt 3 — the old DecorationType struct lived in Decoration.swift
// (now deleted). The Artifact catalog lives here, colocated with promo /
// ad / staff / tenant data tables for symmetry.

// v9 Prompt 6.5 fix — pathing classification per artifact type.
//
// Drives visitor obstacle avoidance. Adding a new ArtifactType requires
// also picking a pathingClass in that type's ArtifactTypeInfo — the
// compiler's exhaustive-init check makes this self-documenting.
//
//   .obstacle — physical object at pedestrian height; visitors must route
//               around it. Also used for architectural objects like railings
//               and sunken seating pits.
//   .floor    — flush with the ground (terrazzo, crackedTile); visitors
//               walk straight over without avoidance.
//   .ceiling  — overhead or wall-mounted above head height (skylights,
//               signage, hanging fluorescents, long-expired holiday decor);
//               never interacts with corridor pathing.
enum ArtifactPathingClass: String, Codable, CaseIterable {
    case obstacle, floor, ceiling
}

struct ArtifactTypeInfo: Equatable {
    let type: ArtifactType
    let name: String
    let baseMult: Double
    let ruinMult: Double
    let size: CGSize
    let cost: Int             // 0 = not player-placeable (ambient / event-spawned)
    let repair: Int
    let description: String
    let defaultTriggers: [String]   // placeholder thought pool per type
    // v9 Prompt 6.5 fix — consumed by MallScene's local-artifact avoidance.
    // See ArtifactPathingClass for the three-class taxonomy.
    let pathingClass: ArtifactPathingClass
}

// v8: DECORATION_TYPES (kugel / fountain / plant / neon / bench / directory).
// v9 Prompt 3 — expanded to full Artifact catalog: 6 preserved decoration
// kinds (identical baseMult/ruinMult/cost/repair/size to v8 for parity) plus
// 20 new Prompt 3 types. Ambient / event-spawned types (boardedStorefront,
// sealedEntrance, emptyFoodCourt, custom) have cost == 0 and are filtered out
// of the Acquire tab.
//
// Thought trigger pools are placeholder strings per the Prompt 1 convention.
// Real prose authoring is deferred (highest-leverage creative work; should
// happen intentionally, not by Claude Code defaults).
enum ArtifactCatalog {

    // v9 Prompt 6.5 fix — convenience accessor for the avoidance/pathing system
    // so consumers don't have to construct the full ArtifactTypeInfo just to
    // ask about pathing class.
    static func pathingClass(for type: ArtifactType) -> ArtifactPathingClass {
        info(type).pathingClass
    }

    static func info(_ type: ArtifactType) -> ArtifactTypeInfo {
        switch type {

        // MARK: - Preserved Decoration kinds (v8 parity)

        case .kugelBall:
            // v8: DECORATION_TYPES.kugel
            return ArtifactTypeInfo(
                type: .kugelBall, name: "Kugel Ball",
                baseMult: 0.15, ruinMult: 0.30,
                size: CGSize(width: 50, height: 50),
                cost: 3500, repair: 800,
                description: "Granite sphere on water.",
                defaultTriggers: [
                    "[placeholder: kugel ball thought 1]",
                    "[placeholder: kugel ball thought 2]",
                    "[placeholder: kugel ball thought 3]",
                ],
                pathingClass: .obstacle)
        case .fountain:
            // v8: DECORATION_TYPES.fountain
            return ArtifactTypeInfo(
                type: .fountain, name: "Fountain",
                baseMult: 0.10, ruinMult: 0.25,
                size: CGSize(width: 80, height: 80),
                cost: 2500, repair: 600,
                description: "Pennies stay when it stops.",
                defaultTriggers: [
                    "[placeholder: fountain thought 1]",
                    "[placeholder: fountain thought 2]",
                    "[placeholder: fountain thought 3]",
                ],
                pathingClass: .obstacle)
        case .planter:
            // v8: DECORATION_TYPES.plant
            return ArtifactTypeInfo(
                type: .planter, name: "Planter",
                baseMult: 0.03, ruinMult: 0.08,
                size: CGSize(width: 18, height: 18),
                cost: 400, repair: 100,
                description: "A ficus.",
                defaultTriggers: [
                    "[placeholder: planter thought 1]",
                    "[placeholder: planter thought 2]",
                    "[placeholder: planter thought 3]",
                ],
                pathingClass: .obstacle)
        case .neonSign:
            // v8: DECORATION_TYPES.neon
            return ArtifactTypeInfo(
                type: .neonSign, name: "Neon Sign",
                baseMult: 0.08, ruinMult: 0.20,
                size: CGSize(width: 40, height: 14),
                cost: 1200, repair: 300,
                description: "Flickering is peak liminal.",
                defaultTriggers: [
                    "[placeholder: neon sign thought 1]",
                    "[placeholder: neon sign thought 2]",
                    "[placeholder: neon sign thought 3]",
                ],
                pathingClass: .ceiling)
        case .bench:
            // v8: DECORATION_TYPES.bench
            return ArtifactTypeInfo(
                type: .bench, name: "Bench",
                baseMult: 0.02, ruinMult: 0.05,
                size: CGSize(width: 50, height: 14),
                cost: 600, repair: 150,
                description: "Mall walkers rest here.",
                defaultTriggers: [
                    "[placeholder: bench thought 1]",
                    "[placeholder: bench thought 2]",
                    "[placeholder: bench thought 3]",
                ],
                pathingClass: .obstacle)
        case .directoryBoard:
            // v8: DECORATION_TYPES.directory
            return ArtifactTypeInfo(
                type: .directoryBoard, name: "Directory Board",
                baseMult: 0.05, ruinMult: 0.15,
                size: CGSize(width: 32, height: 48),
                cost: 1500, repair: 400,
                description: "Never update it.",
                defaultTriggers: [
                    "[placeholder: directory board thought 1]",
                    "[placeholder: directory board thought 2]",
                    "[placeholder: directory board thought 3]",
                ],
                pathingClass: .obstacle)

        // MARK: - Seed-set new types (Prompt 3)

        case .skylight:
            // v9 Prompt 3 — new
            return ArtifactTypeInfo(
                type: .skylight, name: "Skylight",
                baseMult: 0.12, ruinMult: 0.28,
                size: CGSize(width: 60, height: 20),
                cost: 3000, repair: 700,
                description: "Light through cracked glass.",
                defaultTriggers: [
                    "[placeholder: skylight thought 1]",
                    "[placeholder: skylight thought 2]",
                    "[placeholder: skylight thought 3]",
                ],
                pathingClass: .ceiling)
        case .terrazzoFlooring:
            // v9 Prompt 3 — new
            return ArtifactTypeInfo(
                type: .terrazzoFlooring, name: "Terrazzo Flooring",
                baseMult: 0.08, ruinMult: 0.22,
                size: CGSize(width: 80, height: 20),
                cost: 2000, repair: 500,
                description: "Original '80s terrazzo.",
                defaultTriggers: [
                    "[placeholder: terrazzo flooring thought 1]",
                    "[placeholder: terrazzo flooring thought 2]",
                    "[placeholder: terrazzo flooring thought 3]",
                ],
                pathingClass: .floor)

        // MARK: - Prompt 3 roster expansion

        case .payPhoneBank:
            return ArtifactTypeInfo(
                type: .payPhoneBank, name: "Pay Phone Bank",
                baseMult: 0.07, ruinMult: 0.18,
                size: CGSize(width: 48, height: 32),
                cost: 900, repair: 250,
                description: "Nobody uses them.",
                defaultTriggers: [
                    "[placeholder: pay phone bank thought 1]",
                    "[placeholder: pay phone bank thought 2]",
                    "[placeholder: pay phone bank thought 3]",
                ],
                pathingClass: .obstacle)
        case .cigaretteVendingMachine:
            return ArtifactTypeInfo(
                type: .cigaretteVendingMachine, name: "Cigarette Machine",
                baseMult: 0.06, ruinMult: 0.16,
                size: CGSize(width: 18, height: 30),
                cost: 700, repair: 200,
                description: "Unplugged. Never removed.",
                defaultTriggers: [
                    "[placeholder: cigarette vending thought 1]",
                    "[placeholder: cigarette vending thought 2]",
                    "[placeholder: cigarette vending thought 3]",
                ],
                pathingClass: .obstacle)
        case .coinOperatedHorseRide:
            return ArtifactTypeInfo(
                type: .coinOperatedHorseRide, name: "Coin Horse",
                baseMult: 0.09, ruinMult: 0.22,
                size: CGSize(width: 40, height: 36),
                cost: 1100, repair: 300,
                description: "Twenty-five cents, still.",
                defaultTriggers: [
                    "[placeholder: coin horse thought 1]",
                    "[placeholder: coin horse thought 2]",
                    "[placeholder: coin horse thought 3]",
                ],
                pathingClass: .obstacle)
        case .photoBooth:
            return ArtifactTypeInfo(
                type: .photoBooth, name: "Photo Booth",
                baseMult: 0.10, ruinMult: 0.24,
                size: CGSize(width: 30, height: 48),
                cost: 1400, repair: 350,
                description: "Curtain torn halfway.",
                defaultTriggers: [
                    "[placeholder: photo booth thought 1]",
                    "[placeholder: photo booth thought 2]",
                    "[placeholder: photo booth thought 3]",
                ],
                pathingClass: .obstacle)
        case .massageChair:
            return ArtifactTypeInfo(
                type: .massageChair, name: "Massage Chair",
                baseMult: 0.05, ruinMult: 0.14,
                size: CGSize(width: 24, height: 22),
                cost: 900, repair: 250,
                description: "Shake-your-fillings-loose era.",
                defaultTriggers: [
                    "[placeholder: massage chair thought 1]",
                    "[placeholder: massage chair thought 2]",
                    "[placeholder: massage chair thought 3]",
                ],
                pathingClass: .obstacle)
        case .brassRailing:
            return ArtifactTypeInfo(
                type: .brassRailing, name: "Brass Railing",
                baseMult: 0.06, ruinMult: 0.18,
                size: CGSize(width: 60, height: 6),
                cost: 800, repair: 200,
                description: "Tarnished patina.",
                defaultTriggers: [
                    "[placeholder: brass railing thought 1]",
                    "[placeholder: brass railing thought 2]",
                    "[placeholder: brass railing thought 3]",
                ],
                pathingClass: .obstacle)
        case .terrazzoInlay:
            return ArtifactTypeInfo(
                type: .terrazzoInlay, name: "Terrazzo Inlay",
                baseMult: 0.07, ruinMult: 0.20,
                size: CGSize(width: 40, height: 16),
                cost: 1100, repair: 300,
                description: "The mall's seal, set in stone.",
                defaultTriggers: [
                    "[placeholder: terrazzo inlay thought 1]",
                    "[placeholder: terrazzo inlay thought 2]",
                    "[placeholder: terrazzo inlay thought 3]",
                ],
                pathingClass: .floor)
        case .sunkenSeatingPit:
            return ArtifactTypeInfo(
                type: .sunkenSeatingPit, name: "Conversation Pit",
                baseMult: 0.12, ruinMult: 0.28,
                size: CGSize(width: 100, height: 50),
                cost: 2200, repair: 500,
                description: "Nobody sits in it.",
                defaultTriggers: [
                    "[placeholder: sunken seating thought 1]",
                    "[placeholder: sunken seating thought 2]",
                    "[placeholder: sunken seating thought 3]",
                ],
                pathingClass: .obstacle)
        case .deadFicus:
            return ArtifactTypeInfo(
                type: .deadFicus, name: "Dead Ficus",
                baseMult: 0.04, ruinMult: 0.10,
                size: CGSize(width: 18, height: 20),
                cost: 300, repair: 80,
                description: "A planter nobody waters.",
                defaultTriggers: [
                    "[placeholder: dead ficus thought 1]",
                    "[placeholder: dead ficus thought 2]",
                    "[placeholder: dead ficus thought 3]",
                ],
                pathingClass: .obstacle)
        case .waterStainedCeiling:
            return ArtifactTypeInfo(
                type: .waterStainedCeiling, name: "Stained Ceiling Tile",
                baseMult: 0.05, ruinMult: 0.14,
                size: CGSize(width: 20, height: 20),
                cost: 200, repair: 80,
                description: "Tannin-colored halo.",
                defaultTriggers: [
                    "[placeholder: water-stained ceiling thought 1]",
                    "[placeholder: water-stained ceiling thought 2]",
                    "[placeholder: water-stained ceiling thought 3]",
                ],
                pathingClass: .ceiling)
        case .flickeringFluorescent:
            return ArtifactTypeInfo(
                type: .flickeringFluorescent, name: "Flickering Fluorescent",
                baseMult: 0.06, ruinMult: 0.18,
                size: CGSize(width: 36, height: 8),
                cost: 400, repair: 100,
                description: "Never fully on, never fully off.",
                defaultTriggers: [
                    "[placeholder: flickering fluorescent thought 1]",
                    "[placeholder: flickering fluorescent thought 2]",
                    "[placeholder: flickering fluorescent thought 3]",
                ],
                pathingClass: .ceiling)
        case .emergencyExitSign:
            return ArtifactTypeInfo(
                type: .emergencyExitSign, name: "Emergency Exit Sign",
                baseMult: 0.04, ruinMult: 0.10,
                size: CGSize(width: 24, height: 12),
                cost: 300, repair: 80,
                description: "Always lit, never used.",
                defaultTriggers: [
                    "[placeholder: emergency exit sign thought 1]",
                    "[placeholder: emergency exit sign thought 2]",
                    "[placeholder: emergency exit sign thought 3]",
                ],
                pathingClass: .ceiling)
        case .arcadeCabinet:
            return ArtifactTypeInfo(
                type: .arcadeCabinet, name: "Arcade Cabinet",
                baseMult: 0.11, ruinMult: 0.26,
                size: CGSize(width: 28, height: 44),
                cost: 1800, repair: 450,
                description: "Decommissioned. Screen dark.",
                defaultTriggers: [
                    "[placeholder: arcade cabinet thought 1]",
                    "[placeholder: arcade cabinet thought 2]",
                    "[placeholder: arcade cabinet thought 3]",
                ],
                pathingClass: .obstacle)
        case .christmasLeftUp:
            return ArtifactTypeInfo(
                type: .christmasLeftUp, name: "Stale Christmas Decor",
                baseMult: 0.08, ruinMult: 0.20,
                size: CGSize(width: 40, height: 16),
                cost: 500, repair: 120,
                description: "Still up in March.",
                defaultTriggers: [
                    "[placeholder: stale christmas thought 1]",
                    "[placeholder: stale christmas thought 2]",
                    "[placeholder: stale christmas thought 3]",
                ],
                pathingClass: .ceiling)
        case .lostAndFoundCabinet:
            return ArtifactTypeInfo(
                type: .lostAndFoundCabinet, name: "Lost & Found",
                baseMult: 0.05, ruinMult: 0.14,
                size: CGSize(width: 22, height: 24),
                cost: 400, repair: 100,
                description: "Sunglasses older than some visitors.",
                defaultTriggers: [
                    "[placeholder: lost and found thought 1]",
                    "[placeholder: lost and found thought 2]",
                    "[placeholder: lost and found thought 3]",
                ],
                pathingClass: .obstacle)
        case .pretzelRemnant:
            return ArtifactTypeInfo(
                type: .pretzelRemnant, name: "Pretzel Kiosk Remnant",
                baseMult: 0.07, ruinMult: 0.18,
                size: CGSize(width: 28, height: 24),
                cost: 600, repair: 150,
                description: "Counter still smells faintly of butter.",
                defaultTriggers: [
                    "[placeholder: pretzel remnant thought 1]",
                    "[placeholder: pretzel remnant thought 2]",
                    "[placeholder: pretzel remnant thought 3]",
                ],
                pathingClass: .obstacle)
        case .crackedTile:
            return ArtifactTypeInfo(
                type: .crackedTile, name: "Cracked Tile",
                baseMult: 0.04, ruinMult: 0.12,
                size: CGSize(width: 24, height: 16),
                cost: 200, repair: 60,
                description: "Caution tape left too long.",
                defaultTriggers: [
                    "[placeholder: cracked tile thought 1]",
                    "[placeholder: cracked tile thought 2]",
                    "[placeholder: cracked tile thought 3]",
                ],
                pathingClass: .floor)
        case .memorialBench:
            return ArtifactTypeInfo(
                type: .memorialBench, name: "Memorial Bench",
                baseMult: 0.05, ruinMult: 0.14,
                size: CGSize(width: 50, height: 14),
                cost: 700, repair: 180,
                description: "\"In Loving Memory of someone.\"",
                defaultTriggers: [
                    "[placeholder: memorial bench thought 1]",
                    "[placeholder: memorial bench thought 2]",
                    "[placeholder: memorial bench thought 3]",
                ],
                pathingClass: .obstacle)

        // MARK: - Ambient / event-spawned (cost == 0)

        case .boardedStorefront:
            // v9 Prompt 2 — tenant closure memorial. No mult contribution
            // intended for now; scoring integration lands in Prompt 5.
            return ArtifactTypeInfo(
                type: .boardedStorefront, name: "Boarded Storefront",
                baseMult: 0, ruinMult: 0,
                size: CGSize(width: 100, height: 90),
                cost: 0, repair: 0,
                description: "Where a tenant used to be.",
                defaultTriggers: [
                    "[placeholder: boarded storefront thought 1]",
                    "[placeholder: boarded storefront thought 2]",
                    "[placeholder: boarded storefront thought 3]",
                ],
                pathingClass: .obstacle)
        case .sealedStorefront:
            // v9 Prompt 7 — player-chosen terminal state for a boardedStorefront.
            // No tenant offers, no $350 vacancy penalty, 0.5× memory accrual.
            // Size/shape mirrors boardedStorefront (occupies a full slot).
            return ArtifactTypeInfo(
                type: .sealedStorefront, name: "Sealed Storefront",
                baseMult: 0, ruinMult: 0,
                size: CGSize(width: 100, height: 90),
                cost: 0, repair: 0,
                description: "Drywalled over. The mall has given up on this space.",
                defaultTriggers: [
                    "[placeholder: sealed storefront thought 1]",
                    "[placeholder: sealed storefront thought 2]",
                    "[placeholder: sealed storefront thought 3]",
                ],
                pathingClass: .obstacle)
        case .displaySpace:
            // v9 Prompt 7 — non-commercial curated window. +$75/mo maintenance,
            // 1.5× memory accrual. Content variant lives on Artifact.displayContent
            // and overrides thoughtTriggers at conversion time; this catalog
            // entry's defaultTriggers is a generic fallback that shouldn't
            // normally be seen by the UI.
            return ArtifactTypeInfo(
                type: .displaySpace, name: "Display Space",
                baseMult: 0, ruinMult: 0,
                size: CGSize(width: 100, height: 90),
                cost: 0, repair: 0,
                description: "Curated in absence of a tenant.",
                defaultTriggers: [
                    "[placeholder: display space fallback thought 1]",
                    "[placeholder: display space fallback thought 2]",
                    "[placeholder: display space fallback thought 3]",
                ],
                pathingClass: .obstacle)
        case .sealedEntrance:
            return ArtifactTypeInfo(
                type: .sealedEntrance, name: "Sealed Entrance",
                baseMult: 0, ruinMult: 0,
                size: CGSize(width: 40, height: 24),
                cost: 0, repair: 0,
                description: "Boarded-over doors.",
                defaultTriggers: [
                    "[placeholder: sealed entrance thought 1]",
                    "[placeholder: sealed entrance thought 2]",
                    "[placeholder: sealed entrance thought 3]",
                ],
                pathingClass: .obstacle)
        case .emptyFoodCourt:
            return ArtifactTypeInfo(
                type: .emptyFoodCourt, name: "Empty Food Court",
                baseMult: 0, ruinMult: 0,
                size: CGSize(width: 120, height: 80),
                cost: 0, repair: 0,
                description: "Trays stacked, forgotten.",
                defaultTriggers: [
                    "[placeholder: empty food court thought 1]",
                    "[placeholder: empty food court thought 2]",
                    "[placeholder: empty food court thought 3]",
                ],
                pathingClass: .floor)
        case .custom:
            return ArtifactTypeInfo(
                type: .custom, name: "Artifact",
                baseMult: 0, ruinMult: 0,
                size: CGSize(width: 24, height: 24),
                cost: 0, repair: 0,
                description: "Scripted artifact.",
                defaultTriggers: [
                    "[placeholder: custom artifact thought 1]",
                    "[placeholder: custom artifact thought 2]",
                    "[placeholder: custom artifact thought 3]",
                ],
                pathingClass: .obstacle)
        }
    }

    // v9 Prompt 3 — the Acquire tab filters to types with cost > 0.
    static var placeableTypes: [ArtifactType] {
        ArtifactType.allCases.filter { info($0).cost > 0 }
    }
}

// v8: PROMOTIONS
enum Promotions {
    static let all: [Promotion] = [
        Promotion(id: "marketing",   name: "Marketing Campaign",     cost: 3000, duration: 3,
                  description: "+25% traffic for 3 months. +$2k/mo operating.",
                  monthlyCost: 2000, effect: .traffic, bonus: 0),
        Promotion(id: "sale",        name: "Mall-Wide Sale",          cost: 1500, duration: 2,
                  description: "+15% traffic, tenants pay -20% rent.",
                  monthlyCost: 0, effect: .sale, bonus: 0),
        Promotion(id: "holiday",     name: "Holiday Decor",           cost: 2000, duration: 4,
                  description: "+20% traffic for 4 months. Score multiplier drops.",
                  monthlyCost: 0, effect: .holiday, bonus: 0),
        Promotion(id: "carshow",     name: "Parking Lot Car Show",    cost:  800, duration: 1,
                  description: "One-time: +40% traffic. $3k revenue.",
                  monthlyCost: 0, effect: .oneshot, bonus: 3000),
        Promotion(id: "fleamarket",  name: "Weekend Flea Market",     cost:  500, duration: 2,
                  description: "+10% traffic, +$1.5k/mo. Reputation penalty.",
                  monthlyCost: -1500, effect: .flea, bonus: 0),
        Promotion(id: "ghosttour",   name: "Ghost Tour Rental",       cost:    0, duration: 3,
                  description: "No cost. +$1k/mo. Weird visitors.",
                  monthlyCost: -1000, effect: .ghost, bonus: 0),
    ]

    static func find(_ id: String) -> Promotion? { all.first { $0.id == id } }
}

// v8: AD_DEALS
enum AdDeals {
    static let all: [AdDeal] = [
        AdDeal(id: "billboard", name: "Interior Billboard",
               cost: 0, income: 1500, aestheticPenalty: 0.15,
               description: "$1.5k/mo. Large billboard."),
        AdDeal(id: "naming",    name: "Sell Naming Rights",
               cost: 0, income: 3000, aestheticPenalty: 0.4,
               description: "$3k/mo. \"The BellWave Experience.\""),
        AdDeal(id: "floor",     name: "Floor Decals",
               cost: 0, income:  800, aestheticPenalty: 0.08,
               description: "$800/mo. Sticker ads."),
    ]

    static func find(_ id: String) -> AdDeal? { all.first { $0.id == id } }
}

// v8: STAFF_TYPES
enum StaffTypes {
    static let all: [String: StaffType] = [
        "security":    StaffType(key: "security",    name: "Security",        cost: 2000,
                                  description: "Prevents gang events. Reduces shoplifting."),
        "janitorial":  StaffType(key: "janitorial",  name: "Janitorial",      cost: 1500,
                                  description: "Slows artifact decay by 50%."),
        "maintenance": StaffType(key: "maintenance", name: "Maintenance",     cost: 1800,
                                  description: "Reduces disaster frequency."),
        "marketing":   StaffType(key: "marketing",   name: "Marketing Dept.", cost: 1200,
                                  description: "+5% traffic baseline."),
    ]
}

// v8: TENANT_TARGETS_ALL + offerPool()
enum Tenants {

    static let targetsAll: [TenantTarget] = [
        TenantTarget(name: "The Edition",       tier: .standard, rent: 1100, traffic: 60, threshold: 30, lease: 36,
                     approachCost: 2000, requiredStates: [.thriving, .fading]),
        TenantTarget(name: "Basin & Bloom", tier: .standard, rent: 1200, traffic: 70, threshold: 35, lease: 36,
                     approachCost: 2500, requiredStates: [.thriving, .fading]),
        TenantTarget(name: "GameVault",          tier: .standard, rent:  750, traffic: 50, threshold: 25, lease: 24,
                     approachCost: 1200, requiredStates: [.thriving, .fading, .struggling]),
        TenantTarget(name: "BellWave",          tier: .standard, rent:  800, traffic: 40, threshold: 20, lease: 24,
                     approachCost: 1500, requiredStates: [.fading, .struggling]),
        TenantTarget(name: "Via Roma",            tier: .kiosk,    rent:  400, traffic: 32, threshold: 18, lease: 18,
                     approachCost:  800, requiredStates: [.thriving, .fading, .struggling]),
        TenantTarget(name: "Phantasm Seasonal",  tier: .kiosk,    rent:  250, traffic: 22, threshold: 15, lease:  4,
                     approachCost:  300, requiredStates: [.struggling, .dying, .dead]),
        TenantTarget(name: "Escape Room",       tier: .sketchy,  rent:  400, traffic: 16, threshold:  5, lease: 24,
                     approachCost:  500, requiredStates: [.struggling, .dying, .dead]),
        TenantTarget(name: "Pawn Outlet",       tier: .sketchy,  rent:  220, traffic: 10, threshold:  0, lease: 12,
                     approachCost:  200, requiredStates: [.dying, .dead]),
        TenantTarget(name: "Vape Shop",         tier: .sketchy,  rent:  180, traffic:  8, threshold:  0, lease: 12,
                     approachCost:  100, requiredStates: [.struggling, .dying, .dead]),
    ]

    // v8: offerPool()
    private static let good: [TenantOffer] = [
        TenantOffer(name: "The Edition",       tier: .standard, rent: 1100, traffic: 60, threshold: 30, lease: 36, pitch: "National chain."),
        TenantOffer(name: "Basin & Bloom", tier: .standard, rent: 1200, traffic: 70, threshold: 35, lease: 36, pitch: "Saturday crowds."),
    ]
    private static let mid: [TenantOffer] = [
        TenantOffer(name: "GameVault", tier: .standard, rent: 750, traffic: 50, threshold: 25, lease: 24, pitch: "Teen traffic."),
        TenantOffer(name: "BellWave", tier: .standard, rent: 800, traffic: 40, threshold: 20, lease: 24, pitch: "Cell phone store."),
        TenantOffer(name: "Via Roma",   tier: .kiosk,    rent: 400, traffic: 32, threshold: 18, lease: 18, pitch: "Food court pizza."),
    ]
    private static let sketchy: [TenantOffer] = [
        TenantOffer(name: "Phantasm Seasonal", tier: .kiosk,   rent: 250, traffic: 22, threshold: 15, lease:  4, pitch: "Seasonal."),
        TenantOffer(name: "Escape Room",      tier: .sketchy, rent: 400, traffic: 16, threshold:  5, lease: 24, pitch: "\"The liminal vibe.\""),
    ]
    private static let desperate: [TenantOffer] = [
        TenantOffer(name: "Vape Shop",   tier: .sketchy, rent: 180, traffic:  8, threshold: 0, lease: 12, pitch: "Never leaves."),
        TenantOffer(name: "Pawn Outlet", tier: .sketchy, rent: 220, traffic: 10, threshold: 0, lease: 12, pitch: "Cash in hand."),
    ]

    static func offerPool(for state: MallState) -> [TenantOffer] {
        switch state {
        case .thriving:   return good + good + mid
        case .fading:     return mid + mid + good + sketchy
        case .struggling: return sketchy + sketchy + mid + desperate
        case .dying:      return desperate + desperate + sketchy
        case .dead:       return desperate
        }
    }
}
