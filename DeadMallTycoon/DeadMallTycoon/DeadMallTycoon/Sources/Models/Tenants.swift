import Foundation

// v8: offerPool() result entries
// v9 Prompt 17 — `immuneToTrafficClosure` flag propagates to the signed
// Store. Defaults false so existing catalog entries remain unaffected.
struct TenantOffer: Equatable, Codable {
    let name: String
    let tier: StoreTier
    let rent: Int
    let traffic: Int
    let threshold: Int
    let lease: Int
    let pitch: String
    var immuneToTrafficClosure: Bool = false
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
    var immuneToTrafficClosure: Bool = false
}
