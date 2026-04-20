import Foundation

// v8: offerPool() result entries
struct TenantOffer: Equatable, Codable {
    let name: String
    let tier: StoreTier
    let rent: Int
    let traffic: Int
    let threshold: Int
    let lease: Int
    let pitch: String
}

// v8: TENANT_TARGETS_ALL entry
struct TenantTarget: Equatable {
    let name: String
    let tier: StoreTier
    let rent: Int
    let traffic: Int
    let threshold: Int
    let lease: Int
    let approachCost: Int
    let requiredStates: [MallState]
}
