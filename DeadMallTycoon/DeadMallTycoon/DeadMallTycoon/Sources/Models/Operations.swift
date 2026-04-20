import Foundation

// v8: PROMOTIONS entry
struct Promotion: Identifiable, Equatable {
    let id: String
    let name: String
    let cost: Int
    let duration: Int
    let description: String
    let monthlyCost: Int             // negative = revenue, positive = expense
    let effect: PromoEffect
    let bonus: Int                   // one-time (e.g. car show)
}

enum PromoEffect: String {
    case traffic, sale, holiday, oneshot, flea, ghost
}

// v8: G.activePromos entries
struct ActivePromotion: Identifiable, Equatable {
    let id: String
    let name: String
    let cost: Int
    let duration: Int
    let description: String
    let monthlyCost: Int
    let effect: PromoEffect
    let bonus: Int
    var remaining: Int

    init(from p: Promotion, remaining: Int) {
        self.id = p.id
        self.name = p.name
        self.cost = p.cost
        self.duration = p.duration
        self.description = p.description
        self.monthlyCost = p.monthlyCost
        self.effect = p.effect
        self.bonus = p.bonus
        self.remaining = remaining
    }
}

// v8: AD_DEALS entry
struct AdDeal: Identifiable, Equatable {
    let id: String
    let name: String
    let cost: Int
    let income: Int
    let aestheticPenalty: Double
    let description: String
}

// v8: STAFF_TYPES entry
struct StaffType: Equatable {
    let key: String
    let name: String
    let cost: Int
    let description: String
}

// v8: G.activeStaff map
struct StaffLoadout: Equatable, Codable {
    var security: Bool = false
    var janitorial: Bool = false
    var maintenance: Bool = false
    var marketing: Bool = false
}
