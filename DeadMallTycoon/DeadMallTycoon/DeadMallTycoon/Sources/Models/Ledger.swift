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
// v9 Prompt 9 Phase A — expanded beyond closures to cover the full run's
// provenance: artifact creation, decay transitions, destruction, environmental
// state advances, anchor departures, and visitor-attention milestones. Phase A
// wires emission only (no UI); LedgerTemplates.line(for:) renders the cases
// as placeholder strings pending authoring.
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

    // v9 Prompt 9 Phase A — a new artifact entered state.artifacts via a
    // non-closure path.
    //
    // Emitted by:
    //   - ArtifactActions.place (player-placed via the Acquire tab)
    //   - future event-spawned creation paths (not wired in Phase A)
    //
    // Deliberately NOT emitted by TenantLifecycle.vacateSlot. The spawned
    // boardedStorefront memorial IS a new artifact, but the .closure /
    // .anchorDeparture entry already narrates that moment; a second
    // .artifactCreated line would be redundant. Consumers needing the
    // artifactId for a closure-spawned memorial look it up via slotId.
    // NOT emitted by StartingMall.buildStartingArtifacts — starting-seed
    // artifacts pre-exist the run and would be noise in the ledger.
    // NOT emitted by the seal/display/revert verbs — those mutate an
    // existing artifact in place and already have their own ledger cases.
    case artifactCreated(
        artifactId: Int,
        name: String,
        type: ArtifactType,
        origin: ArtifactOrigin,
        year: Int,
        month: Int
    )

    // v9 Prompt 9 Phase A — an artifact's condition advanced one step.
    //
    // Emitted from TickEngine's decay loop (step 5) for every rng-triggered
    // increment. Condition goes 0..4 (Pristine → Ruin), so up to four
    // decayTransition entries fire over an artifact's lifetime. Ambient/
    // memorial types (boardedStorefront, sealed, display, etc.) are frozen
    // and never decay → never emit.
    case decayTransition(
        artifactId: Int,
        name: String,
        type: ArtifactType,
        fromCondition: Int,
        toCondition: Int,
        year: Int,
        month: Int
    )

    // v9 Prompt 9 Phase A — an artifact was destroyed for a reason outside
    // the offer-destruction path (which has its own dedicated case).
    //
    // Emission deliberately unwired in Phase A — there is no such path in
    // current mechanics. Reserved for future destruction events (fire,
    // flood, vandalism). The reason string is free-form at emission time
    // since it's authored per event.
    case artifactDestroyed(
        artifactId: Int,
        name: String,
        type: ArtifactType,
        reason: String,
        year: Int,
        month: Int
    )

    // v9 Prompt 9 Phase A — the mall crossed into a new environmental state
    // (thriving → fading, etc., including the Prompt 8 ghostMall terminal).
    //
    // Detected in TickEngine by comparing EnvironmentState.from(state) at
    // tick start vs tick end; one entry per direction-change. Does NOT
    // distinguish decline from recovery — the `from`/`to` pair makes the
    // direction explicit.
    case envTransition(
        from: EnvironmentState,
        to: EnvironmentState,
        year: Int,
        month: Int
    )

    // v9 Prompt 9 Phase A — an anchor tenant departed. Replaces the
    // generic .closure entry for anchor-tier closures so the ledger can
    // narrate the full cascade as a single weighty moment.
    //
    // `trafficDelta` is the traffic the mall loses with this anchor
    // (negative number, since traffic goes down). `coincidentClosureNames`
    // is the list of non-anchor tenant names closing in the same tick —
    // lets the ledger render "Halvorsen left; two standards followed."
    // `slotId` and `year`/`month` mirror ClosureEvent for cross-referencing.
    //
    // Non-anchor closures continue to emit .closure. No tenant closure
    // ever emits both cases.
    case anchorDeparture(
        tenantName: String,
        wing: Wing,
        trafficDelta: Int,
        coincidentClosureNames: [String],
        yearsOpen: Int,
        slotId: Int,
        year: Int,
        month: Int
    )

    // v9 Prompt 9 Phase A — an artifact's thoughtReferenceCount crossed
    // a milestone threshold. Thresholds: {10, 50, 100, 500, 1000}.
    //
    // Emitted from GameViewModel.recordThoughtFired when the post-increment
    // count lands exactly on a threshold. Each threshold fires at most
    // once per artifact — subsequent thoughts at the same count do nothing.
    case attentionMilestone(
        artifactId: Int,
        name: String,
        type: ArtifactType,
        threshold: Int,
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
    var isArtifactCreated: Bool {
        if case .artifactCreated = self { return true }
        return false
    }
    var isDecayTransition: Bool {
        if case .decayTransition = self { return true }
        return false
    }
    var isArtifactDestroyed: Bool {
        if case .artifactDestroyed = self { return true }
        return false
    }
    var isEnvTransition: Bool {
        if case .envTransition = self { return true }
        return false
    }
    var isAnchorDeparture: Bool {
        if case .anchorDeparture = self { return true }
        return false
    }
    var isAttentionMilestone: Bool {
        if case .attentionMilestone = self { return true }
        return false
    }
}

// v9 Prompt 9 Phase A — thresholds for .attentionMilestone emission.
// Sparse and intentional: each represents a different "the mall is
// noticing this" beat. Fixed set so the ledger reads consistently
// across runs; see TUNING.md for rationale.
extension LedgerEntry {
    static let attentionMilestoneThresholds: [Int] = [10, 50, 100, 500, 1000]
}

// v9 Prompt 9 Phase B — timestamp accessors. Every case carries a
// (year, month) pair; these expose it uniformly so consumers (the
// year-grouper, future Phase C focus-by-time helpers) don't have to
// re-pattern-match per case.
extension LedgerEntry {
    var year: Int {
        switch self {
        case .closure(let ev):                                       return ev.year
        case .offerDestruction(_, _, _, _, _, let y, _):             return y
        case .artifactSealed(_, _, _, _, let y, _):                  return y
        case .displayConversion(_, _, _, _, let y, _):               return y
        case .displayReverted(_, _, _, _, let y, _):                 return y
        case .artifactCreated(_, _, _, _, let y, _):                 return y
        case .decayTransition(_, _, _, _, _, let y, _):              return y
        case .artifactDestroyed(_, _, _, _, let y, _):               return y
        case .envTransition(_, _, let y, _):                         return y
        case .anchorDeparture(_, _, _, _, _, _, let y, _):           return y
        case .attentionMilestone(_, _, _, _, let y, _):              return y
        }
    }

    var month: Int {
        switch self {
        case .closure(let ev):                                       return ev.month
        case .offerDestruction(_, _, _, _, _, _, let m):             return m
        case .artifactSealed(_, _, _, _, _, let m):                  return m
        case .displayConversion(_, _, _, _, _, let m):               return m
        case .displayReverted(_, _, _, _, _, let m):                 return m
        case .artifactCreated(_, _, _, _, _, let m):                 return m
        case .decayTransition(_, _, _, _, _, _, let m):              return m
        case .artifactDestroyed(_, _, _, _, _, let m):               return m
        case .envTransition(_, _, _, let m):                         return m
        case .anchorDeparture(_, _, _, _, _, _, _, let m):           return m
        case .attentionMilestone(_, _, _, _, _, let m):              return m
        }
    }
}
