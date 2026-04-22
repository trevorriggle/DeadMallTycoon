import Foundation

// Player-action services. All are pure (inout GameState + RNG where needed, returning new state).
// v8 counterparts: acceptTenant, declineTenant, evictStore, adjustRent, runStorePromo,
// approachTenant, beginPlacement/placementClickHandler, repairDec, removeDec,
// toggleWingClosed, toggleWingDowngrade, launchPromo, toggleAdDeal, toggleStaff.

// v9 Prompt 6 — memorial cost displayed on the tenant-offer banner when
// accepting would destroy a boardedStorefront memorial. Pure value type so
// SwiftUI can diff it without reference tracking.
struct MemorialCost: Equatable {
    let artifactId: Int
    let tenantName: String
    let yearsBoarded: Int
    let memoryWeight: Double
    let thoughtReferenceCount: Int
}

enum StoreActions {

    // v9 Prompt 6 — the slot that acceptOffer WOULD fill, if called now.
    // Extracted so the offer UI can look up the prospective slot to render
    // the memorial-cost line. Matches acceptOffer's selection exactly:
    // first vacant open slot, anchor-to-anchor / non-anchor-to-non-anchor.
    //
    // v9 Prompt 7 — slots that carry a sealedStorefront OR displaySpace
    // artifact are LOCKED from the offer pool. Both verbs are thesis-aligned
    // curation actions — the player chose what the space becomes, so no
    // future tenant is eligible for it. Sealed is permanent; display is
    // reversible via ArtifactActions.revertToBoarded.
    static func prospectiveSlotIndex(for offer: TenantOffer, in state: GameState) -> Int? {
        let offerIsAnchor = offer.tier == .anchor
        let lockedSlotIds: Set<Int> = Set(
            state.artifacts
                .filter { $0.type == .sealedStorefront || $0.type == .displaySpace }
                .compactMap { $0.storeSlotId }
        )
        return state.stores.firstIndex(where: { store in
            let slotIsAnchor = store.position.w >= 180
            return store.tier == .vacant
                && !Mall.isWingClosed(store.wing, in: state)
                && !lockedSlotIds.contains(store.id)
                && slotIsAnchor == offerIsAnchor
        })
    }

    // v9 Prompt 6 — resolve the boardedStorefront memorial on the prospective
    // slot, if any. Returns nil for fresh vacancies (no prior tenant) and for
    // offers that have no compatible slot.
    //
    // Defensive tiebreaker: if more than one boardedStorefront references
    // the same slot (shouldn't happen — closures only hit occupied slots and
    // slots can't be re-closed before being re-occupied), pick the most
    // recent by artifact id.
    static func memorialCost(for offer: TenantOffer, in state: GameState) -> MemorialCost? {
        guard let idx = prospectiveSlotIndex(for: offer, in: state) else { return nil }
        let slotId = state.stores[idx].id
        let candidates = state.artifacts.filter {
            $0.type == .boardedStorefront && $0.storeSlotId == slotId
        }
        guard let artifact = candidates.max(by: { $0.id < $1.id }) else { return nil }
        return MemorialCost(
            artifactId: artifact.id,
            tenantName: artifact.name,
            yearsBoarded: max(0, state.year - artifact.yearCreated),
            memoryWeight: artifact.memoryWeight,
            thoughtReferenceCount: artifact.thoughtReferenceCount
        )
    }

    // v8: acceptTenant()
    // Anchor slot gate: a slot with w >= 180 (the two department-store end-caps) only
    // accepts an anchor-tier offer, and anchor-tier offers only go to anchor slots.
    // If no compatible slot exists, the decision is cleared without filling — matching
    // v8 behavior for "no vacant slot" but extended to respect architectural size.
    //
    // v9 Prompt 6 — when the chosen slot carries a boardedStorefront memorial,
    // accepting destroys it (removes from state.artifacts) and appends a
    // .offerDestruction LedgerEntry with a snapshot of the memorial's final
    // state. Declining leaves the artifact untouched (see declineOffer).
    static func acceptOffer(_ state: GameState) -> GameState {
        var s = state
        guard case .tenant(let offer) = s.decision else { return s }
        let offerIsAnchor = offer.tier == .anchor
        guard let vi = s.stores.firstIndex(where: { store in
            let slotIsAnchor = store.position.w >= 180
            return store.tier == .vacant
                && !Mall.isWingClosed(store.wing, in: s)
                && slotIsAnchor == offerIsAnchor
        }) else {
            s.decision = nil; s.paused = false
            return s
        }

        // v9 Prompt 6 — memorial destruction on accept. Compute BEFORE the slot
        // mutation so the lookup still matches by storeSlotId, and take the
        // snapshot for the ledger before removing the artifact.
        let slotId = s.stores[vi].id
        let memorialCandidates = s.artifacts.filter {
            $0.type == .boardedStorefront && $0.storeSlotId == slotId
        }
        if let memorial = memorialCandidates.max(by: { $0.id < $1.id }) {
            s.ledger.append(.offerDestruction(
                tenantName: memorial.name,
                newTenantName: offer.name,
                yearsBoarded: max(0, s.year - memorial.yearCreated),
                memoryWeight: memorial.memoryWeight,
                thoughtReferenceCount: memorial.thoughtReferenceCount,
                year: s.year,
                month: s.month
            ))
            s.artifacts.removeAll { $0.id == memorial.id }
        }

        let pos = s.stores[vi].position
        s.stores[vi] = Store(
            id: s.stores[vi].id,
            name: offer.name, tier: offer.tier,
            rent: offer.rent, originalRent: offer.rent,
            rentMultiplier: 1.0,
            traffic: offer.traffic, threshold: offer.threshold,
            lease: offer.lease, hardship: 0,
            closing: false, leaving: false,
            monthsOccupied: 0, monthsVacant: 0,
            promotionActive: false,
            position: pos
        )
        s.decision = nil
        s.paused = false
        return s
    }

    // v8: declineTenant()
    static func declineOffer(_ state: GameState) -> GameState {
        var s = state
        guard case .tenant = s.decision else { return s }
        s.decision = nil
        s.paused = false
        return s
    }

    // v8: evictStore()
    // v9: slot vacate routed through TenantLifecycle so an evicted tenant also
    // leaves behind a memorial boardedStorefront artifact. Score penalty,
    // selection clearing, and slot transition mechanics are unchanged.
    static func evict(storeId: Int, _ state: GameState) -> GameState {
        var s = state
        guard let idx = s.stores.firstIndex(where: { $0.id == storeId }) else { return s }
        if s.stores[idx].tier == .vacant { return s }
        let penalty = Int(Double(s.score) * 0.2) + 200
        s.score = max(0, s.score - penalty)
        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)
        if s.selectedStoreId == storeId { s.selectedStoreId = nil }
        return s
    }

    // v8: adjustRent()
    static func adjustRent(storeId: Int, delta: Double, _ state: GameState) -> GameState {
        var s = state
        guard let idx = s.stores.firstIndex(where: { $0.id == storeId }) else { return s }
        let old = s.stores[idx].rentMultiplier
        let newMult = max(0.5, min(2.0, old + delta))
        s.stores[idx].rentMultiplier = newMult
        s.stores[idx].rent = Int(Double(s.stores[idx].originalRent) * newMult)
        if newMult > 1.3 {
            s.stores[idx].hardship = min(4, s.stores[idx].hardship + 0.5)
        }
        return s
    }

    // v8: runStorePromo()
    static func runPromo(storeId: Int, _ state: GameState) -> GameState {
        var s = state
        guard let idx = s.stores.firstIndex(where: { $0.id == storeId }) else { return s }
        if s.cash < 500 || s.stores[idx].promotionActive { return s }
        s.cash -= 500
        s.stores[idx].promotionActive = true
        return s
    }

    // v8: approachTenant()
    static func approach(targetIndex: Int, _ state: GameState,
                         rng: inout some RandomNumberGenerator) -> (state: GameState, success: Bool) {
        var s = state
        guard targetIndex >= 0, targetIndex < Tenants.targetsAll.count else { return (s, false) }
        let target = Tenants.targetsAll[targetIndex]
        if s.cash < target.approachCost { return (s, false) }
        let mallState = Mall.state(s)
        if !target.requiredStates.contains(mallState) { return (s, false) }
        let targetIsAnchor = target.tier == .anchor
        guard let vi = s.stores.firstIndex(where: { store in
            let slotIsAnchor = store.position.w >= 180
            return store.tier == .vacant
                && !Mall.isWingClosed(store.wing, in: s)
                && slotIsAnchor == targetIsAnchor
        }) else { return (s, false) }

        s.cash -= target.approachCost

        let trafficMod: Double = {
            if s.currentTraffic > target.threshold * 3 { return 0.2 }
            if s.currentTraffic < target.threshold     { return -0.3 }
            return 0
        }()
        let baseRate: Double = {
            switch mallState {
            case .thriving:   return 0.8
            case .fading:     return 0.65
            case .struggling: return 0.5
            case .dying:      return 0.35
            case .dead:       return 0.2
            }
        }()
        let success = rng.chance(baseRate + trafficMod)
        if success {
            let pos = s.stores[vi].position
            s.stores[vi] = Store(
                id: s.stores[vi].id,
                name: target.name, tier: target.tier,
                rent: target.rent, originalRent: target.rent,
                rentMultiplier: 1.0,
                traffic: target.traffic, threshold: target.threshold,
                lease: target.lease, hardship: 0,
                closing: false, leaving: false,
                monthsOccupied: 0, monthsVacant: 0,
                promotionActive: false,
                position: pos
            )
        }
        return (s, success)
    }
}

// v8: beginPlacement / placementClickHandler / repairDec / removeDec — the
// decoration player-action surface. v9 Prompt 3 — renamed to ArtifactActions,
// operates on the unified Artifact model. Same cost/placement/repair/remove
// mechanics, new home. The old DecorationActions enum is deleted.
enum ArtifactActions {

    // v8: beginPlacement / placementClickHandler
    // v9 Prompt 3 — type is any ArtifactType with catalog cost > 0.
    static func place(type: ArtifactType,
                      at point: (x: Double, y: Double),
                      _ state: GameState) -> GameState {
        var s = state
        let info = ArtifactCatalog.info(type)
        if info.cost <= 0 { return s }                // not player-placeable
        if s.cash < info.cost { return s }
        // v8: corridor constraint y in [200, 320]
        if point.y < 200 || point.y > 320 { return s }
        s.cash -= info.cost
        let newId = (s.artifacts.map(\.id).max() ?? 0) + 1
        s.artifacts.append(ArtifactFactory.make(
            id: newId,
            type: type,
            name: info.name,
            origin: .playerAction("placed"),
            yearCreated: s.year,
            x: point.x - info.size.width  / 2,
            y: point.y - info.size.height / 2
        ))
        s.placingArtifactType = nil
        return s
    }

    // v8: repairDec()
    // v9 Prompt 3 — operates on Artifact (cost looked up via catalog).
    static func repair(artifactId: Int, _ state: GameState) -> GameState {
        var s = state
        guard let idx = s.artifacts.firstIndex(where: { $0.id == artifactId }) else { return s }
        let info = ArtifactCatalog.info(s.artifacts[idx].type)
        if info.repair <= 0 { return s }              // ambient types aren't repairable
        if s.cash < info.repair { return s }
        s.cash -= info.repair
        s.artifacts[idx].condition = max(0, s.artifacts[idx].condition - 2)
        s.artifacts[idx].hazard = false
        s.artifacts[idx].monthsAtCondition = 0
        return s
    }

    // v8: removeDec()
    static func remove(artifactId: Int, _ state: GameState) -> GameState {
        var s = state
        s.artifacts.removeAll { $0.id == artifactId }
        if s.selectedDecorationId == artifactId { s.selectedDecorationId = nil }
        return s
    }
}

enum WingActions {

    // v8: toggleWingClosed()
    static func toggleClosed(_ wing: Wing, _ state: GameState) -> GameState {
        var s = state
        let current = s.wingsClosed[wing] ?? false
        s.wingsClosed[wing] = !current
        if !current { s.wingsDowngraded[wing] = false }   // sealing clears downgrade
        return s
    }

    // v8: toggleWingDowngrade()
    static func toggleDowngrade(_ wing: Wing, _ state: GameState) -> GameState {
        var s = state
        if s.wingsClosed[wing] ?? false { return s }     // can't downgrade sealed wing
        let current = s.wingsDowngraded[wing] ?? false
        s.wingsDowngraded[wing] = !current
        return s
    }
}

enum PromoActions {

    // v8: launchPromo()
    static func launch(_ promoId: String, _ state: GameState) -> GameState {
        var s = state
        guard let p = Promotions.find(promoId) else { return s }
        if s.cash < p.cost { return s }
        if s.activePromos.contains(where: { $0.id == p.id }) { return s }
        s.cash -= p.cost
        if p.bonus > 0 { s.cash += p.bonus }
        s.activePromos.append(ActivePromotion(from: p, remaining: p.duration))
        return s
    }

    // v8: toggleAdDeal()
    static func toggleAdDeal(_ dealId: String, _ state: GameState) -> GameState {
        var s = state
        guard let deal = AdDeals.find(dealId) else { return s }
        if let i = s.activeAdDeals.firstIndex(where: { $0.id == dealId }) {
            s.activeAdDeals.remove(at: i)
        } else {
            s.activeAdDeals.append(deal)
        }
        return s
    }

    // v8: toggleStaff()
    static func toggleStaff(_ key: String, _ state: GameState) -> GameState {
        var s = state
        switch key {
        case "security":    s.activeStaff.security    = !s.activeStaff.security
        case "janitorial":  s.activeStaff.janitorial  = !s.activeStaff.janitorial
        case "maintenance": s.activeStaff.maintenance = !s.activeStaff.maintenance
        case "marketing":   s.activeStaff.marketing   = !s.activeStaff.marketing
        default: break
        }
        return s
    }
}
