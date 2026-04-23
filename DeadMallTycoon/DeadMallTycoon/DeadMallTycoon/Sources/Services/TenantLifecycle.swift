import Foundation
import CoreGraphics

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
        //
        // v9 Prompt 10 Phase A — anchor departure ALSO triggers the wing
        // cascade: a cluster of ambient artifacts spawns (degraded
        // skylight, stopped escalator, lost signage), the wing's traffic
        // multiplier drops 25%, the wing's env state offset bumps +1
        // band, and a 3-month hardship stagger queues for in-wing non-
        // anchor tenants. Guarded by anchorDepartedWings so the cascade
        // fires once per wing per run.
        if tenantTier == .anchor {
            if !s.anchorDepartedWings.contains(wing) {
                s = applyAnchorDepartureCascade(
                    to: s, wing: wing, anchorName: tenantName)
            }
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

    // MARK: v9 Prompt 10 Phase A — anchor departure cascade

    // Fires once per wing per run (guarded by anchorDepartedWings at the
    // call site). Spawns the three cluster artifacts at wing-relative
    // coordinates, sets the wing's permanent damage fields, and queues
    // the 3-month hardship stagger. Does NOT spawn the boardedStorefront
    // memorial — the caller already does that via ArtifactFactory.make
    // after the slot vacates.
    //
    // Cluster positions are intentionally hand-picked (not randomized)
    // so the same anchor always produces the same cluster layout — tests
    // can pin exact coords, and repeat playthroughs recognize "oh, the
    // escalator is right there again." Positions are in CSS/world coords
    // (y-down from top-left origin). The scene's csToScene flip handles
    // rendering in Phase C.
    private static func applyAnchorDepartureCascade(
        to state: GameState,
        wing: Wing,
        anchorName: String
    ) -> GameState {
        var s = state
        s.anchorDepartedWings.insert(wing)
        s.wingTrafficMultipliers[wing] = 0.75
        s.wingEnvOffsets[wing] = (s.wingEnvOffsets[wing] ?? 0) + 1
        s.pendingWingHardshipMonths[wing] = 3

        let positions = clusterPositions(for: wing)
        let origin: ArtifactOrigin = .event(name: "anchor departure: \(anchorName)")
        var nextId = (s.artifacts.map(\.id).max() ?? 0) + 1

        // 1. Stopped escalator at wing entry (just outside the anchor
        //    block, in the main corridor).
        s.artifacts.append(ArtifactFactory.make(
            id: nextId, type: .stoppedEscalator,
            name: ArtifactCatalog.info(.stoppedEscalator).name,
            origin: origin, yearCreated: s.year,
            x: positions.escalator.x, y: positions.escalator.y
        ))
        nextId += 1

        // 2. Deteriorating skylight — existing .skylight type at condition 3.
        //    "Deteriorating" in the Condition ladder is exactly condition 3;
        //    no new artifact type needed (per Q1 decision).
        var skylight = ArtifactFactory.make(
            id: nextId, type: .skylight,
            name: ArtifactCatalog.info(.skylight).name,
            origin: origin, yearCreated: s.year,
            x: positions.skylight.x, y: positions.skylight.y
        )
        skylight.condition = 3
        s.artifacts.append(skylight)
        nextId += 1

        // 3. Lost signage on the corridor floor near the anchor.
        s.artifacts.append(ArtifactFactory.make(
            id: nextId, type: .lostSignage,
            name: ArtifactCatalog.info(.lostSignage).name,
            origin: origin, yearCreated: s.year,
            x: positions.signage.x, y: positions.signage.y
        ))

        return s
    }

    // Cluster position table. North wing's anchor is the west column
    // (x:0..200, y:200..1200); south wing's anchor is the east column
    // (x:1000..1200, y:200..1200). Positions are mirrored across both
    // axes for the two wings. Coords are CSS (top-left origin, y-down).
    private static func clusterPositions(
        for wing: Wing
    ) -> (escalator: CGPoint, skylight: CGPoint, signage: CGPoint) {
        switch wing {
        case .north:
            // North anchor is the WEST column. Cluster sits on the east
            // side of the anchor, inside the main corridor band.
            return (
                escalator: CGPoint(x: 230, y: 260),  // wing entry, top of main corridor
                skylight:  CGPoint(x: 550, y: 130),  // upper access corridor above shop row
                signage:   CGPoint(x: 270, y: 700)   // main corridor floor near anchor
            )
        case .south:
            // South anchor is the EAST column. Cluster mirrors to the
            // west side of that anchor.
            return (
                escalator: CGPoint(x: 930, y: 1140), // wing entry, bottom of main corridor
                skylight:  CGPoint(x: 650, y: 1270), // lower access corridor below shop row
                signage:   CGPoint(x: 900, y: 700)   // main corridor floor near anchor
            )
        }
    }
}
