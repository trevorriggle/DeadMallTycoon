import Foundation

// v9 Prompt 7 — memorial verbs: Seal and Display.
//
// Three actions on boardedStorefront / displaySpace artifacts. All three
// mutate the artifact IN PLACE (same id, same storeSlotId, preserved
// memoryWeight / thoughtReferenceCount / yearCreated / condition). Only the
// type, thoughtTriggers, and displayContent change. This preserves the
// memorial's accumulated provenance — a sealed or displayed slot remembers
// everything the boarded slot did.
//
// Gating:
//   sealStorefront      — works on .boardedStorefront OR .displaySpace.
//   repurposeAsDisplay  — works on .boardedStorefront only.
//   revertToBoarded     — works on .displaySpace only.
//
// Invalid calls are clean no-ops (return state unchanged). UI never offers
// an ineligible verb in the inspector, so these no-op paths are defensive.
//
// Each successful action appends a LedgerEntry to state.ledger. Prompt 8
// surfaces the ledger UI; these entries are data-only for now.
enum ArtifactActions {

    // Seal a boardedStorefront or displaySpace permanently. Irreversible.
    // Slot leaves the offer pool (see StoreActions.prospectiveSlotIndex) and
    // stops incurring the $350 vacancy penalty (see Economy.operatingCost).
    // Memory accrual drops to 0.5× going forward (see
    // GameViewModel.recordThoughtFired).
    static func sealStorefront(artifactId: Int, _ state: GameState) -> GameState {
        var s = state
        guard let idx = s.artifacts.firstIndex(where: { $0.id == artifactId }) else { return s }
        let a = s.artifacts[idx]
        guard a.type == .boardedStorefront || a.type == .displaySpace else { return s }

        // Snapshot for the ledger BEFORE mutation.
        let entry = LedgerEntry.artifactSealed(
            tenantName: a.name,
            sourceType: a.type,
            memoryWeight: a.memoryWeight,
            thoughtReferenceCount: a.thoughtReferenceCount,
            year: s.year,
            month: s.month
        )

        // In-place type mutation preserves id, storeSlotId, memoryWeight,
        // thoughtReferenceCount, yearCreated, condition, monthsAtCondition.
        s.artifacts[idx].type = .sealedStorefront
        s.artifacts[idx].displayContent = nil
        s.artifacts[idx].thoughtTriggers =
            ArtifactFactory.defaultThoughtTriggers(for: .sealedStorefront)

        s.ledger.append(entry)
        return s
    }

    // Repurpose a boardedStorefront into a displaySpace with the specified
    // content. Caller (GameViewModel) picks content via seeded rng; tests
    // can call directly with a deterministic content choice.
    static func repurposeAsDisplay(artifactId: Int,
                                    content: DisplayContent,
                                    _ state: GameState) -> GameState {
        var s = state
        guard let idx = s.artifacts.firstIndex(where: { $0.id == artifactId }) else { return s }
        let a = s.artifacts[idx]
        guard a.type == .boardedStorefront else { return s }

        let entry = LedgerEntry.displayConversion(
            tenantName: a.name,
            content: content,
            memoryWeight: a.memoryWeight,
            thoughtReferenceCount: a.thoughtReferenceCount,
            year: s.year,
            month: s.month
        )

        s.artifacts[idx].type = .displaySpace
        s.artifacts[idx].displayContent = content
        // DisplayContent's per-variant thought pool becomes the artifact's
        // trigger pool; visitor thoughts lean into the curated content.
        s.artifacts[idx].thoughtTriggers = content.thoughtPool

        s.ledger.append(entry)
        return s
    }

    // Revert a displaySpace back to a boardedStorefront. Refunds future
    // maintenance (via Economy.operatingCost's per-tick read) and drops
    // memory accrual back to 1.0×.
    //
    // Non-goal: re-repurposing after revert picks a fresh random content —
    // the prior displayContent is intentionally forgotten.
    static func revertToBoarded(artifactId: Int, _ state: GameState) -> GameState {
        var s = state
        guard let idx = s.artifacts.firstIndex(where: { $0.id == artifactId }) else { return s }
        let a = s.artifacts[idx]
        guard a.type == .displaySpace else { return s }
        // content is non-nil for a well-formed displaySpace; defensive fallback.
        let content = a.displayContent ?? .historicalPlaque

        let entry = LedgerEntry.displayReverted(
            tenantName: a.name,
            content: content,
            memoryWeight: a.memoryWeight,
            thoughtReferenceCount: a.thoughtReferenceCount,
            year: s.year,
            month: s.month
        )

        s.artifacts[idx].type = .boardedStorefront
        s.artifacts[idx].displayContent = nil
        s.artifacts[idx].thoughtTriggers =
            ArtifactFactory.defaultThoughtTriggers(for: .boardedStorefront)

        s.ledger.append(entry)
        return s
    }
}
