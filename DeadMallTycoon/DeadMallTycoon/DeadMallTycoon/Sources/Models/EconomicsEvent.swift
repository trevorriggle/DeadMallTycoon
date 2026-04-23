import Foundation

// v9 Prompt 15 Phase 1 — transient per-tick economics trace for scene
// rendering. TickEngine populates this each tick at the economics step;
// MallScene consumes during reconcile to spawn floating +$N / -$N
// indicators above the relevant source. Events are replaced (not
// appended) each tick, so the scene always reads the current month's
// flows.
//
// Three cases, chosen so every cash-affecting line item has a visible
// source:
//   - rentCollected: per tenant storefront (positive; staggered ~100ms)
//   - hazardFine:    per hazardous artifact (negative; concurrent)
//   - operatingCost: aggregate mall-wide (negative; single indicator at
//                    mall top, no single source). Covers base ops +
//                    staff + promo cost.
//
// Ad revenue and promo revenue deliberately omitted from Phase 1 —
// they're mall-wide too but lower frequency; can add later without
// changing the event shape.
enum EconomicsEvent: Equatable, Codable {
    case rentCollected(storeId: Int, amount: Int)
    case hazardFine(artifactId: Int, amount: Int)
    case operatingCost(amount: Int)
}
