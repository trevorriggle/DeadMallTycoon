import Foundation

// v9 Prompt 10 Phase B — anchor departure modal card payload.
//
// Written by TenantLifecycle.vacateSlot when an anchor closes, consumed by
// AnchorDepartureCardView rendered inside MallView. Separate from the
// .anchorDeparture LedgerEntry: the ledger entry is the durable provenance
// record; this payload is the transient UI trigger that gets popped after
// the player acknowledges it. Queue lives in GameState so observation
// drives the UI automatically.
struct AnchorDepartureCardPayload: Equatable, Identifiable, Codable {
    let id: UUID
    let tenantName: String
    let wing: Wing
    let yearsOpen: Int
}
