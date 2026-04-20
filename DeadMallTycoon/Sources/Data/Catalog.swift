import Foundation
import CoreGraphics

// v8: DECORATION_TYPES
enum DecorationTypes {
    static let all: [DecorationKind: DecorationType] = [
        .kugel: DecorationType(
            kind: .kugel, name: "Kugel Ball",
            baseMult: 0.15, ruinMult: 0.30,
            size: CGSize(width: 28, height: 28),
            cost: 3500, repair: 800,
            description: "Granite sphere on water."),
        .fountain: DecorationType(
            kind: .fountain, name: "Fountain",
            baseMult: 0.10, ruinMult: 0.25,
            size: CGSize(width: 46, height: 46),
            cost: 2500, repair: 600,
            description: "Pennies stay when it stops."),
        .plant: DecorationType(
            kind: .plant, name: "Planter",
            baseMult: 0.03, ruinMult: 0.08,
            size: CGSize(width: 18, height: 18),
            cost: 400, repair: 100,
            description: "A ficus."),
        .neon: DecorationType(
            kind: .neon, name: "Neon Sign",
            baseMult: 0.08, ruinMult: 0.20,
            size: CGSize(width: 40, height: 14),
            cost: 1200, repair: 300,
            description: "Flickering is peak liminal."),
        .bench: DecorationType(
            kind: .bench, name: "Bench",
            baseMult: 0.02, ruinMult: 0.05,
            size: CGSize(width: 36, height: 10),
            cost: 600, repair: 150,
            description: "Mall walkers rest here."),
        .directory: DecorationType(
            kind: .directory, name: "Directory Board",
            baseMult: 0.05, ruinMult: 0.15,
            size: CGSize(width: 22, height: 30),
            cost: 1500, repair: 400,
            description: "Never update it."),
    ]

    static func type(_ kind: DecorationKind) -> DecorationType {
        all[kind]!
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
               description: "$3k/mo. \"The Cingular Experience.\""),
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
                                  description: "Slows decoration decay by 50%."),
        "maintenance": StaffType(key: "maintenance", name: "Maintenance",     cost: 1800,
                                  description: "Reduces disaster frequency."),
        "marketing":   StaffType(key: "marketing",   name: "Marketing Dept.", cost: 1200,
                                  description: "+5% traffic baseline."),
    ]
}

// v8: TENANT_TARGETS_ALL + offerPool()
enum Tenants {

    static let targetsAll: [TenantTarget] = [
        TenantTarget(name: "The Limited",       tier: .standard, rent: 1100, traffic: 60, threshold: 30, lease: 36,
                     approachCost: 2000, requiredStates: [.thriving, .fading]),
        TenantTarget(name: "Bath & Body Works", tier: .standard, rent: 1200, traffic: 70, threshold: 35, lease: 36,
                     approachCost: 2500, requiredStates: [.thriving, .fading]),
        TenantTarget(name: "GameStop",          tier: .standard, rent:  750, traffic: 50, threshold: 25, lease: 24,
                     approachCost: 1200, requiredStates: [.thriving, .fading, .struggling]),
        TenantTarget(name: "Cingular",          tier: .standard, rent:  800, traffic: 40, threshold: 20, lease: 24,
                     approachCost: 1500, requiredStates: [.fading, .struggling]),
        TenantTarget(name: "Sbarro",            tier: .kiosk,    rent:  400, traffic: 32, threshold: 18, lease: 18,
                     approachCost:  800, requiredStates: [.thriving, .fading, .struggling]),
        TenantTarget(name: "Spirit Halloween",  tier: .kiosk,    rent:  250, traffic: 22, threshold: 15, lease:  4,
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
        TenantOffer(name: "The Limited",       tier: .standard, rent: 1100, traffic: 60, threshold: 30, lease: 36, pitch: "National chain."),
        TenantOffer(name: "Bath & Body Works", tier: .standard, rent: 1200, traffic: 70, threshold: 35, lease: 36, pitch: "Saturday crowds."),
    ]
    private static let mid: [TenantOffer] = [
        TenantOffer(name: "GameStop", tier: .standard, rent: 750, traffic: 50, threshold: 25, lease: 24, pitch: "Teen traffic."),
        TenantOffer(name: "Cingular", tier: .standard, rent: 800, traffic: 40, threshold: 20, lease: 24, pitch: "Cell phone store."),
        TenantOffer(name: "Sbarro",   tier: .kiosk,    rent: 400, traffic: 32, threshold: 18, lease: 18, pitch: "Food court pizza."),
    ]
    private static let sketchy: [TenantOffer] = [
        TenantOffer(name: "Spirit Halloween", tier: .kiosk,   rent: 250, traffic: 22, threshold: 15, lease:  4, pitch: "Seasonal."),
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
