import Foundation

// Player-action services. All are pure (inout GameState + RNG where needed, returning new state).
// v8 counterparts: acceptTenant, declineTenant, evictStore, adjustRent, runStorePromo,
// approachTenant, beginPlacement/placementClickHandler, repairDec, removeDec,
// toggleWingClosed, toggleWingDowngrade, launchPromo, toggleAdDeal, toggleStaff.

enum StoreActions {

    // v8: acceptTenant()
    // Anchor slot gate: a slot with w >= 180 (the two department-store end-caps) only
    // accepts an anchor-tier offer, and anchor-tier offers only go to anchor slots.
    // If no compatible slot exists, the decision is cleared without filling — matching
    // v8 behavior for "no vacant slot" but extended to respect architectural size.
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
    static func evict(storeId: Int, _ state: GameState) -> GameState {
        var s = state
        guard let idx = s.stores.firstIndex(where: { $0.id == storeId }) else { return s }
        if s.stores[idx].tier == .vacant { return s }
        let penalty = Int(Double(s.score) * 0.2) + 200
        s.score = max(0, s.score - penalty)
        s.stores[idx] = Store.vacant(id: s.stores[idx].id, at: s.stores[idx].position)
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

enum DecorationActions {

    // v8: beginPlacement / placementClickHandler
    static func place(kind: DecorationKind, at point: (x: Double, y: Double), _ state: GameState) -> GameState {
        var s = state
        let type = DecorationTypes.type(kind)
        if s.cash < type.cost { return s }
        // v8: corridor constraint y in [200, 320]
        if point.y < 200 || point.y > 320 { return s }
        s.cash -= type.cost
        let newId = (s.decorations.map(\.id).max() ?? 0) + 1
        s.decorations.append(Decoration(
            id: newId, kind: kind,
            x: point.x - type.size.width  / 2,
            y: point.y - type.size.height / 2,
            condition: 0, working: true, hazard: false,
            monthsAtCondition: 0
        ))
        s.placingDecoration = nil
        return s
    }

    // v8: repairDec()
    static func repair(decorationId: Int, _ state: GameState) -> GameState {
        var s = state
        guard let idx = s.decorations.firstIndex(where: { $0.id == decorationId }) else { return s }
        let type = DecorationTypes.type(s.decorations[idx].kind)
        if s.cash < type.repair { return s }
        s.cash -= type.repair
        s.decorations[idx].condition = max(0, s.decorations[idx].condition - 2)
        s.decorations[idx].hazard = false
        s.decorations[idx].monthsAtCondition = 0
        return s
    }

    // v8: removeDec()
    static func remove(decorationId: Int, _ state: GameState) -> GameState {
        var s = state
        s.decorations.removeAll { $0.id == decorationId }
        if s.selectedDecorationId == decorationId { s.selectedDecorationId = nil }
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
