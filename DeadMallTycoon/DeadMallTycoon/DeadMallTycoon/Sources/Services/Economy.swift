import Foundation

// All v8 revenue/cost functions ported as pure functions.
// rent, adRevenue, promoCost, promoRevenue, operatingCost, staffCost, hazardFines, rawTraffic, aestheticMult.
enum Economy {

    // v8: rent()
    static func rent(_ state: GameState) -> Int {
        let saleActive = state.activePromos.contains { $0.effect == .sale }
        return state.stores
            .filter { !Mall.isWingClosed($0.wing, in: state) }
            .reduce(0) { acc, s in
                var r = s.rent
                if saleActive { r = Int((Double(r) * 0.8).rounded()) }
                return acc + r
            }
    }

    // v8: adRevenue()
    static func adRevenue(_ state: GameState) -> Int {
        state.activeAdDeals.reduce(0) { $0 + $1.income }
    }

    // v8: promoRevenue()
    static func promoRevenue(_ state: GameState) -> Int {
        state.activePromos.reduce(0) { acc, p in
            acc + (p.monthlyCost < 0 ? -p.monthlyCost : 0)
        }
    }

    // v8: promoCost()
    static func promoCost(_ state: GameState) -> Int {
        state.activePromos.reduce(0) { acc, p in
            acc + (p.monthlyCost > 0 ? p.monthlyCost : 0)
        }
    }

    // v8: staffCost()
    static func staffCost(_ state: GameState) -> Int {
        var cost = 0
        if state.activeStaff.security,    let s = StaffTypes.all["security"]    { cost += s.cost }
        if state.activeStaff.janitorial,  let s = StaffTypes.all["janitorial"]  { cost += s.cost }
        if state.activeStaff.maintenance, let s = StaffTypes.all["maintenance"] { cost += s.cost }
        if state.activeStaff.marketing,   let s = StaffTypes.all["marketing"]   { cost += s.cost }
        return cost
    }

    // v8: operatingCost()
    //
    // v9 Prompt 7 — sealed slots (artifact.type == .sealedStorefront) no longer
    // incur the $350/mo vacancy penalty. The space is walled off and not
    // maintained. Each .displaySpace artifact adds $75/mo maintenance
    // (cleaning, lighting, occasional content refresh).
    static func operatingCost(_ state: GameState) -> Int {
        let openStores = Mall.openStores(state)
        // v9 Prompt 7 — vacant slots with a sealedStorefront artifact opt out
        // of the $350 penalty; everything else is unchanged.
        let sealedSlotIds: Set<Int> = Set(
            state.artifacts
                .filter { $0.type == .sealedStorefront }
                .compactMap { $0.storeSlotId }
        )
        let vac = openStores.filter {
            $0.tier == .vacant && !sealedSlotIds.contains($0.id)
        }.count
        var base = 9500
        if Mall.isWingClosed(.north, in: state) { base -= 2500 }
        if Mall.isWingClosed(.south, in: state) { base -= 2500 }
        let perStore = openStores.count * 500
        let vacancyPenalty = vac * 350
        var downgradeSavings = 0
        if Mall.isWingDowngraded(.north, in: state) { downgradeSavings += 1500 }
        if Mall.isWingDowngraded(.south, in: state) { downgradeSavings += 1500 }
        // v9 Prompt 7 — display-space maintenance. $75/mo per displaySpace.
        let displayCount = state.artifacts.filter { $0.type == .displaySpace }.count
        let displayMaintenance = displayCount * 75
        return max(2000, base + perStore + vacancyPenalty - downgradeSavings + displayMaintenance)
    }

    // v8: hazardFines()
    // v9 Prompt 3 — reads state.artifacts (unified from deleted state.decorations).
    // Only placeable artifacts can carry hazard in practice; ambient/memorial
    // types never set the flag, so no filter-by-type is needed.
    static func hazardFines(_ state: GameState) -> Int {
        state.artifacts
            .filter { $0.hazard }
            .reduce(0) { $0 + 500 + $1.condition * 200 }
    }

    // v8: rawTraffic()
    //
    // v9 Prompt 6.5 — four corner entrances. A diminishing-returns multiplier
    // on open-door count scales the tenant-occupancy factor output. Two open
    // doors = 1.0 (baseline, matching the previous two-wing layout), four
    // open = 1.4, one open = 0.5, zero = 0 (no new visitors enter). The
    // multiplier is applied BEFORE promo / staff / downgrade modifiers so
    // those continue to compound on top of traffic volume.
    static func rawTraffic(_ state: GameState) -> Int {
        let openStores = Mall.openStores(state)
        let occ = openStores.filter { $0.tier != .vacant }.count
        let total = max(1, openStores.count)
        let factor = 0.55 + 0.45 * Double(occ) / Double(total)
        var t = Int(Double(openStores.reduce(0) { $0 + $1.traffic }) * factor)
        // v9 Prompt 6.5 — open-door multiplier.
        t = Int(Double(t) * entranceTrafficMultiplier(openEntranceCount: Mall.openEntranceCount(in: state)))
        for p in state.activePromos {
            switch p.effect {
            case .traffic:  t = Int(Double(t) * 1.25)
            case .sale:     t = Int(Double(t) * 1.15)
            case .holiday:  t = Int(Double(t) * 1.20)
            case .oneshot:  t = Int(Double(t) * 1.40)
            case .flea:     t = Int(Double(t) * 1.10)
            case .ghost:    break
            }
        }
        if Mall.isWingDowngraded(.north, in: state) { t = Int(Double(t) * 0.9) }
        if Mall.isWingDowngraded(.south, in: state) { t = Int(Double(t) * 0.9) }
        if state.activeStaff.marketing { t = Int(Double(t) * 1.05) }
        if state.gangMonths > 0        { t = Int(Double(t) * 0.65) }
        return t
    }

    // v9 Prompt 6.5 — diminishing-returns curve for open-door count.
    // See TUNING.md "Entrances" section. Two open = 1.0 is the calibration
    // anchor; it preserves traffic magnitudes from the previous two-wing
    // layout so other tuning (rent, hardship thresholds) doesn't need
    // recalibration.
    static func entranceTrafficMultiplier(openEntranceCount: Int) -> Double {
        switch openEntranceCount {
        case 0: return 0.0
        case 1: return 0.5
        case 2: return 1.0
        case 3: return 1.2
        default: return 1.4   // 4 (or more, if the topology is ever extended)
        }
    }

    // v8: aestheticMult()
    // v9 Prompt 3 — artifact sum replaces decoration sum. Formula is
    // identical: each placeable artifact contributes
    //   condition >= 4 ? ruinMult : baseMult * (1 + 0.2 * condition)
    // Ambient / memorial artifacts (cost == 0 in catalog) contribute 0 here
    // — their scoring role is introduced in Prompt 5 via memoryWeight.
    //
    // v9 Prompt 5 — aestheticMult is NO LONGER consumed by scoring.
    // Scoring.monthlyScore dropped the `× aesthetic` term in favor of the
    // split-substrate formula (vacancyScore + memoryScore). This function is
    // currently unused but intentionally retained: Prompt 13 (music state
    // machine / ambient signals) may repurpose it as an environmental read.
    // If Prompt 13 ships without consuming it, this function should be
    // deleted at that time. DO NOT re-wire into scoring without a design
    // discussion — the memoryWeight substrate is the intended replacement.
    static func aestheticMult(_ state: GameState) -> Double {
        let totalSlots = max(1, state.stores.count)
        let vacantOpenCount = state.stores
            .filter { $0.tier == .vacant && !Mall.isWingClosed($0.wing, in: state) }
            .count
        var vacMult = 1.0 + Double(vacantOpenCount) / Double(totalSlots) * 1.2
        if Mall.isWingClosed(.north, in: state) { vacMult += 0.3 }
        if Mall.isWingClosed(.south, in: state) { vacMult += 0.3 }

        let artifactSum = state.artifacts.reduce(0.0) { acc, a in
            let info = ArtifactCatalog.info(a.type)
            // cost == 0 → ambient/memorial; no aesthetic contribution (yet).
            guard info.cost > 0 else { return acc }
            let mult = a.condition >= 4
                ? info.ruinMult
                : info.baseMult * (1.0 + Double(a.condition) * 0.2)
            return acc + mult
        }
        let decMult = 1.0 + artifactSum

        let adPenalty = state.activeAdDeals.reduce(0.0) { $0 + $1.aestheticPenalty }

        var promoPenalty = 0.0
        for p in state.activePromos {
            if p.effect == .holiday { promoPenalty += 0.3 }
            if p.effect == .flea    { promoPenalty += 0.2 }
        }

        let raw = vacMult * decMult - adPenalty - promoPenalty
        let rounded = (raw * 10).rounded() / 10
        return max(0.5, rounded)
    }
}
