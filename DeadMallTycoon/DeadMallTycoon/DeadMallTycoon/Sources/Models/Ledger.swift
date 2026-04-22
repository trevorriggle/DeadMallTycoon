import Foundation

// v9 Prompt 6 — ClosureEvent + LedgerEntry.
//
// LedgerEntry is the durable provenance log appended whenever something
// memorial-relevant happens — closures, offer destructions, seal/display
// conversions. Surfaced as UI in Prompt 8's ledger view (forthcoming).
//
// ClosureEvent specifically captures the per-tenant data the ledger needs
// to render a closure entry. Originally also drove the modal closure card
// (since replaced with auto-dismiss Toasts — see Models/Toast.swift); now
// it lives only in the ledger.
//
// Both are value types so GameState's Equatable conformance is preserved.

// A named loss. One entry per closed tenant. Emitted by TenantLifecycle.vacateSlot
// from any route — hardship, lease non-renewal, force eviction, or (Prompt 9)
// anchor cascade. Drives the ClosureEventCard overlay.
struct ClosureEvent: Equatable, Identifiable, Codable {
    // Stable id for SwiftUI diffing while the card is mounted.
    let id: UUID

    // The tenant's name as it existed in the slot at close time. This is the
    // lookup key for ClosureFlavor — exact string match first, tier fallback
    // second, neutral template last.
    let tenantName: String

    // Carried so the flavor-lookup layer can fall back by tier when no
    // per-name line exists. Also lets the card pick the anchor layout.
    let tenantTier: StoreTier

    // Years the tenant held the slot. Derived from Store.monthsOccupied / 12
    // at close time (see Prompt 6 design note: monthsOccupied resets on
    // re-occupancy, so this is accurate for the close-to-close window).
    let yearsOpen: Int

    // Slot id — so ledger consumers can cross-reference with the
    // boardedStorefront artifact that was just spawned, without re-searching.
    let slotId: Int

    // Timestamp at close time. Paired month/year so ledger display can
    // render "March 1987" without pulling in a Date type.
    let year: Int
    let month: Int

    // Anchor layout hint. Derived from tenantTier == .anchor at construction
    // time so the card doesn't have to redo the check each render.
    var isAnchor: Bool { tenantTier == .anchor }
}

// The provenance log. Grows monotonically. Surfaced in Prompt 8's ledger UI.
// Value-type enum so diffing and testing stay simple.
enum LedgerEntry: Equatable, Codable {

    // A tenant closed. Captures the ClosureEvent verbatim so every field
    // the card rendered is preserved in the log.
    case closure(ClosureEvent)

    // A boardedStorefront memorial was destroyed because the player accepted
    // an offer over it. Snapshot-only: the artifact itself is gone from
    // state.artifacts after this entry is written.
    case offerDestruction(
        tenantName: String,
        newTenantName: String,
        yearsBoarded: Int,
        memoryWeight: Double,
        thoughtReferenceCount: Int,
        year: Int,
        month: Int
    )

    // v9 Prompt 7 — player permanently sealed a memorial. Applies to BOTH
    // boardedStorefront→sealed and displaySpace→sealed transitions; `source`
    // records which starting state the artifact came from.
    case artifactSealed(
        tenantName: String,
        sourceType: ArtifactType,
        memoryWeight: Double,
        thoughtReferenceCount: Int,
        year: Int,
        month: Int
    )

    // v9 Prompt 7 — player converted a boardedStorefront into a curated display.
    case displayConversion(
        tenantName: String,
        content: DisplayContent,
        memoryWeight: Double,
        thoughtReferenceCount: Int,
        year: Int,
        month: Int
    )

    // v9 Prompt 7 — player reverted a displaySpace back to a boardedStorefront.
    // Captures the content type being abandoned so the ledger can narrate
    // "the community art installation came down in 1987."
    case displayReverted(
        tenantName: String,
        content: DisplayContent,
        memoryWeight: Double,
        thoughtReferenceCount: Int,
        year: Int,
        month: Int
    )

    // Convenience for UI/test filtering.
    var isClosure: Bool {
        if case .closure = self { return true }
        return false
    }
    var isOfferDestruction: Bool {
        if case .offerDestruction = self { return true }
        return false
    }
    var isArtifactSealed: Bool {
        if case .artifactSealed = self { return true }
        return false
    }
    var isDisplayConversion: Bool {
        if case .displayConversion = self { return true }
        return false
    }
    var isDisplayReverted: Bool {
        if case .displayReverted = self { return true }
        return false
    }
}
