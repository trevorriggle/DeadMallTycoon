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
    // v9 Prompt 6 — vacateSlot also writes a .closure LedgerEntry.
    // v9 patch — surface to player as an auto-dismiss Toast (style:
    // .closure) instead of the original modal ClosureEventCard. No tap
    // required; the ledger remains the durable record.
    //
    // v9 Prompt 9 Phase A — anchor-tier closures route to .anchorDeparture
    // instead of .closure, carrying wing / trafficDelta /
    // coincidentClosureNames so the ledger can render the full cascade as
    // one weighty entry. Non-anchor closures continue to emit .closure.
    //
    // Design note on .artifactCreated: we deliberately do NOT emit it here
    // for the spawned boardedStorefront memorial. The .closure /
    // .anchorDeparture entry already narrates the moment the memorial
    // appeared; a second .artifactCreated line would be redundant noise.
    // .artifactCreated fires only from ArtifactActions.place (player
    // Acquire) and any future event-spawned creation path.
    //
    // `coincidentClosureNames` is passed by TickEngine with the names of the
    // OTHER tenants closing in the same tick (excluding this one). Non-tick
    // callers (StoreActions.evict, direct test invocations) default to [].
    static func vacateSlot(storeIndex: Int,
                           state: GameState,
                           coincidentClosureNames: [String] = []) -> GameState {
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
        let wing = store.wing
        let lostTraffic = store.traffic
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

        // v9 Prompt 9 Phase A — anchor-tier routing. Anchors get a dedicated
        // .anchorDeparture entry carrying the full cascade; non-anchors
        // continue to write .closure as before. No closure ever emits both.
        if tenantTier == .anchor {
            s.ledger.append(.anchorDeparture(
                tenantName: tenantName,
                wing: wing,
                trafficDelta: -lostTraffic,
                coincidentClosureNames: coincidentClosureNames,
                yearsOpen: yearsOpen,
                slotId: slotId,
                year: s.year,
                month: s.month
            ))
        } else {
            let event = ClosureEvent(
                id: UUID(),
                tenantName: tenantName,
                tenantTier: tenantTier,
                yearsOpen: yearsOpen,
                slotId: slotId,
                year: s.year,
                month: s.month
            )
            s.ledger.append(.closure(event))
        }

        // v9 patch — push an auto-dismiss closure toast. Title is the
        // retailer name, subtitle is the authored ClosureFlavor line (or
        // the [flavor line pending] placeholder until copy lands). Built
        // from a lightweight ClosureEvent even for anchors so the existing
        // ClosureFlavor lookup stays keyed on tenant name — the ledger
        // routing diverges but the player-facing toast doesn't.
        let toastEvent = ClosureEvent(
            id: UUID(),
            tenantName: tenantName,
            tenantTier: tenantTier,
            yearsOpen: yearsOpen,
            slotId: slotId,
            year: s.year,
            month: s.month
        )
        let toast = Toast(
            title: tenantName,
            subtitle: ClosureFlavor.line(for: toastEvent),
            style: .closure
        )
        s.toasts.append(toast)

        return s
    }
}
