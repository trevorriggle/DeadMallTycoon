import Foundation

// v8: events produced by buildEvents() + triggerOpeningLawsuit()
enum FlavorEventKind: Equatable {
    case openingLawsuit(settleCost: Int)
    case burstPipes(repairCost: Int)
    case vandalism(cleanupCost: Int)
    case gangActivity(securityCost: Int)
    case cityInspection(cooperateCost: Int)
    case codeViolations(payCost: Int)
    case hvacFailure(repairCost: Int)
}

struct FlavorEvent: Equatable {
    let kind: FlavorEventKind
    let name: String
    let description: String
    let acceptLabel: String
    let declineLabel: String
}

// v8: G.decision
enum Decision: Equatable {
    case tenant(TenantOffer)
    case event(FlavorEvent)
}
