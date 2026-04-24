import Foundation

// All v8 revenue/cost functions ported as pure functions.
// rent, adRevenue, promoCost, promoRevenue, operatingCost, staffCost, hazardFines, rawTraffic, aestheticMult.
enum Economy {

    // v9 Prompt 17 — tuning constants for endgame viability rebalancing.
    // See TUNING.md "Economy" section for design rationale.

    // Monthly savings per fully-sealed wing. Represents HVAC zone
    // shutdown, security patrol reduction, lighting cut, cleaning
    // contract reduction, insurance adjustment. Raised from the v5
    // 2500 after a dying-mall endgame-viability audit showed savings
    // were undervalued by roughly half.
    static let sealedWingSavings: Int = 4500

    // Monthly savings per sealed corner entrance (NW/NE/SW/SE).
    // Represents reduced security presence, lighting, signage
    // maintenance at a closed entry point. Four corners sealed = $2k/mo.
    static let sealedEntranceSavings: Int = 500

    // Per-display-space maintenance cost, scaled by the mall's
    // environmental state. Represents active curation effort —
    // cleaning, refreshing content, adjusting lighting. As the mall
    // declines, that effort decays with it; displays become fossils
    // rather than maintained installations. Ghost Mall's $15 is
    // nominal — a display left alone on a run that's been dead for
    // five years is barely a cost at all.
    static let displayMaintenanceByState: [EnvironmentState: Int] = [
        .thriving:   75,
        .fading:     60,
        .struggling: 45,
        .dying:      30,
        .dead:       20,
        .ghostMall:  15,
    ]

    // Long-tenure loyalty bonus. A tenant that's been open continuously
    // for 10+ years pays 15% more rent — a narrative "regular who
    // believes in the place" beat that mechanically reinforces the
    // endgame-fantasy specialty-tenant-that-stayed-for-decades
    // trope. Applied at rent-collection time via Economy.rentByStore;
    // the displayed rent stays raw so the Prompt 15 Phase 1 floating
    // +$N indicator naturally shows the bumped amount.
    static let longTenureYearsThreshold: Int = 10
    static let longTenureRentMultiplier: Double = 1.15

    // v8: rent()
    // v9 Prompt 15 Phase 1 — implemented via rentByStore for per-
    // storefront breakdown.
    static func rent(_ state: GameState) -> Int {
        rentByStore(state).reduce(0) { $0 + $1.amount }
    }

    // v9 Prompt 15 Phase 1 — per-store rent breakdown. Returns only
    // stores that actually pay rent this tick (non-zero amount after
    // sale and wing-closure filters), so the caller can emit one
    // EconomicsEvent.rentCollected per entry without noise.
    //
    // v9 Prompt 17 — long-tenure loyalty bonus: stores with
    // monthsOccupied >= longTenureYearsThreshold × 12 get a
    // longTenureRentMultiplier (1.15×) bump applied AFTER the sale
    // discount. Displayed rent remains raw — the bump lives only at
    // collection time, so the Prompt 15 Phase 1 floating +$N
    // indicator naturally shows the bumped amount without a separate
    // bonus label.
    static func rentByStore(_ state: GameState) -> [(storeId: Int, amount: Int)] {
        let saleActive = state.activePromos.contains { $0.effect == .sale }
        let longTenureMonths = longTenureYearsThreshold * 12
        return state.stores
            .filter { !Mall.isWingClosed($0.wing, in: state) }
            .compactMap { store in
                let base = store.rent
                guard base > 0 else { return nil }
                var actual = saleActive
                    ? Int((Double(base) * 0.8).rounded())
                    : base
                if store.monthsOccupied >= longTenureMonths {
                    actual = Int((Double(actual) * longTenureRentMultiplier).rounded())
                }
                guard actual > 0 else { return nil }
                return (store.id, actual)
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
    //
    // v9 Prompt 17 — endgame-viability rebalancing:
    //   - Sealed wing savings raised from 2500 → sealedWingSavings (4500).
    //   - New: sealed entrance savings. Each corner in state.sealedEntrances
    //     saves sealedEntranceSavings ($500). Four sealed = $2k/mo.
    //   - Display maintenance scales by EnvironmentState — 75 at thriving
    //     down to 15 at ghostMall. A display that sits in a dead mall
    //     isn't actively curated; it becomes a fossil. Table in
    //     displayMaintenanceByState.
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
        if Mall.isWingClosed(.north, in: state) { base -= sealedWingSavings }
        if Mall.isWingClosed(.south, in: state) { base -= sealedWingSavings }
        // v9 Prompt 17 — per-corner entrance savings. state.sealedEntrances
        // is a Set<EntranceCorner> from Prompt 6.5.
        let entranceSavings = state.sealedEntrances.count * sealedEntranceSavings
        base -= entranceSavings
        let perStore = openStores.count * 500
        let vacancyPenalty = vac * 350
        var downgradeSavings = 0
        if Mall.isWingDowngraded(.north, in: state) { downgradeSavings += 1500 }
        if Mall.isWingDowngraded(.south, in: state) { downgradeSavings += 1500 }
        // v9 Prompt 17 — display maintenance scaled by env state.
        let env = EnvironmentState.from(state)
        let perDisplayMaintenance = displayMaintenanceByState[env] ?? 75
        let displayCount = state.artifacts.filter { $0.type == .displaySpace }.count
        let displayMaintenance = displayCount * perDisplayMaintenance
        return max(2000, base + perStore + vacancyPenalty - downgradeSavings + displayMaintenance)
    }

    // v9 Prompt 19 — preview of operatingCost AFTER applying a SealAction,
    // without mutating the live state. Used by SealConfirmOverlay to render
    // "current: $X/mo → after: $Y/mo" accurately, reusing the canonical
    // operatingCost function rather than reproducing its arithmetic.
    //
    // The mutation mirrors what the confirm path does: for wing/entrance
    // seals, flip the flag; for memorial seals, morph the target artifact
    // to .sealedStorefront. No ledger append, no action burst — we only
    // need the cost surface to match. Returns nil if the action references
    // an entity that no longer exists (artifact deleted, etc.), so callers
    // can fall back to the current cost.
    static func hypotheticalOperatingCost(
        _ state: GameState,
        ifApplying action: SealAction
    ) -> Int? {
        var s = state
        switch action {
        case .wing(let wing):
            s.wingsClosed[wing] = true
            s.wingsDowngraded[wing] = false
        case .entrance(let corner):
            s.sealedEntrances.insert(corner)
        case .memorial(let artifactId):
            guard let idx = s.artifacts.firstIndex(where: { $0.id == artifactId }) else {
                return nil
            }
            let a = s.artifacts[idx]
            guard a.type == .boardedStorefront || a.type == .displaySpace else {
                return nil
            }
            s.artifacts[idx].type = .sealedStorefront
            s.artifacts[idx].displayContent = nil
        }
        return operatingCost(s)
    }

    // v8: hazardFines()
    // v9 Prompt 3 — reads state.artifacts (unified from deleted state.decorations).
    // Only placeable artifacts can carry hazard in practice; ambient/memorial
    // types never set the flag, so no filter-by-type is needed.
    // v9 Prompt 15 Phase 1 — implemented via hazardFinesByArtifact.
    static func hazardFines(_ state: GameState) -> Int {
        hazardFinesByArtifact(state).reduce(0) { $0 + $1.amount }
    }

    // v9 Prompt 15 Phase 1 — per-artifact hazard fine breakdown. Each
    // entry becomes one EconomicsEvent.hazardFine so the scene can
    // float a negative indicator at the offending artifact.
    //
    // v9 Prompt 21 Fix 2 — capped to ArtifactTuning.maxHazardFinesPerTick
    // entries per month (currently 1). All hazarded artifacts remain on
    // scene and continue to motivate repair; only the single largest fine
    // bills per tick so stacked hazards don't dominate cash flow. Ties
    // broken by artifactId (lowest first) for determinism.
    static func hazardFinesByArtifact(_ state: GameState) -> [(artifactId: Int, amount: Int)] {
        let all = state.artifacts
            .filter { $0.hazard }
            .map { (artifactId: $0.id, amount: 500 + $0.condition * 200) }
        let cap = ArtifactTuning.maxHazardFinesPerTick
        guard cap > 0, all.count > cap else { return all }
        return Array(all.sorted {
            $0.amount != $1.amount ? $0.amount > $1.amount
                                   : $0.artifactId < $1.artifactId
        }.prefix(cap))
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
