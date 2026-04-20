import Foundation

// v8: G.stores entries (STARTING_STORES shape merged with STORE_POSITIONS plus runtime fields)
struct Store: Identifiable, Equatable, Codable {
    let id: Int                      // stable slot index matching STORE_POSITIONS
    var name: String
    var tier: StoreTier
    var rent: Int
    var originalRent: Int
    var rentMultiplier: Double       // v8: s.rentMultiplier, clamped 0.5..2.0
    var traffic: Int
    var threshold: Int               // v8: s.thresh
    var lease: Int                   // months remaining
    var hardship: Double             // v8: s.hw
    var closing: Bool
    var leaving: Bool
    var monthsOccupied: Int
    var monthsVacant: Int
    var promotionActive: Bool
    let position: StorePosition

    var wing: Wing { position.wing }
    var isVacant: Bool { tier == .vacant }
    var isOpenForBusiness: Bool { !isVacant }

    static func vacant(id: Int, at position: StorePosition) -> Store {
        Store(
            id: id, name: "", tier: .vacant,
            rent: 0, originalRent: 0, rentMultiplier: 1.0,
            traffic: 0, threshold: 0, lease: 0,
            hardship: 0,
            closing: false, leaving: false,
            monthsOccupied: 0, monthsVacant: 0,
            promotionActive: false,
            position: position
        )
    }
}
