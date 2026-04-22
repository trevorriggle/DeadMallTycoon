import Foundation

// v9: Centralizes the tenant → vacant transition so every path (hardship
// closure, lease non-renewal, force eviction, and future paths like Prompt 9's
// anchor ripple cascade) produces the same memorial effect.
//
// v8 parity note: v8 vacated slots inline at three separate call sites with no
// memorial side effect. The iPad port adds the Artifact memorial here (Prompt 2)
// without altering any mechanic — scoring, hardship, leases, threat, and all
// downstream systems continue to read only from state.stores as before.
enum TenantLifecycle {

    // v9: Vacate a tenant slot and record a memorial artifact.
    //
    // - If the slot is already vacant, no artifact is generated (defensive
    //   no-op; real call sites always pass a populated slot).
    // - Artifact name captures the literal tenant name. UI/thought templates
    //   compose framing ("Former …", "Remember when …", etc.) at render time.
    // - storeSlotId lets future systems look up the slot position without
    //   maintaining a parallel coordinate cache on the artifact.
    // - tenantId is reserved for the future tenant-identity system and left
    //   nil in Prompt 2.
    //
    // v9 Prompt 6 — vacateSlot now also:
    //   - enqueues a ClosureEvent onto state.pendingClosureEvents (drives the
    //     overlay closure card).
    //   - appends a .closure LedgerEntry to state.ledger.
    // Game is NOT paused by either side effect — closure cards are narrative
    // beats the player dismisses at their own cadence.
    static func vacateSlot(storeIndex: Int, state: GameState) -> GameState {
        var s = state
        guard storeIndex >= 0, storeIndex < s.stores.count else { return s }
        let store = s.stores[storeIndex]
        // Defensive: vacating an already-vacant slot is a no-op.
        if store.tier == .vacant { return s }

        // Capture before mutation. Store.name and Store.id are captured eagerly
        // because the vacant replacement zeroes them.
        let tenantName = store.name
        let tenantTier = store.tier
        let slotId = store.id
        // monthsOccupied / 12 → yearsOpen. This is accurate for the close-to-
        // close window because monthsOccupied resets on re-occupancy; it's the
        // best available signal without adding a Store.openedYear field (per
        // Prompt 6 design call: don't add that field until a real bug needs it).
        let yearsOpen = store.monthsOccupied / 12

        // Transition the slot — identical to what each call site did inline.
        s.stores[storeIndex] = Store.vacant(id: slotId, at: store.position)

        // Append the memorial artifact. Id is monotonic from the current max.
        let nextId = (s.artifacts.map(\.id).max() ?? 0) + 1
        let artifact = ArtifactFactory.make(
            id: nextId,
            type: .boardedStorefront,
            name: tenantName,
            origin: .tenant(name: tenantName),
            yearCreated: s.year,
            storeSlotId: slotId,
            tenantId: nil    // reserved for future tenant-identity system
        )
        s.artifacts.append(artifact)

        // v9 Prompt 6 — closure event + ledger entry.
        let event = ClosureEvent(
            id: UUID(),
            tenantName: tenantName,
            tenantTier: tenantTier,
            yearsOpen: yearsOpen,
            slotId: slotId,
            year: s.year,
            month: s.month
        )
        s.pendingClosureEvents.append(event)
        s.ledger.append(.closure(event))

        return s
    }
}
