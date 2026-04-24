import Foundation

// v8: tick()
// The heart. Pure function: takes a GameState and an RNG, returns a new GameState.
// No timers, no rendering, no global mutation. All randomness flows through `rng`
// so tests pin behavior with a seeded generator.
enum TickEngine {

    static func tick(_ state: GameState, rng: inout some RandomNumberGenerator) -> GameState {
        var s = state
        if s.gameover || s.paused || !s.started { return s }

        // v9 Prompt 9 Phase A — capture environmental state at tick start
        // (before any mutation). Compared against post-tick state at the
        // end of the function to emit .envTransition when the mall crosses
        // a band (thriving→fading→…→dead→ghostMall, or any recovery).
        let prevEnv = EnvironmentState.from(state)

        // 1. advance clock — v8: G.m++; if(G.m>=12){G.m=0;G.y++}
        s.month += 1
        if s.month >= 12 { s.month = 0; s.year += 1 }
        let totalMonths = (s.year - GameConstants.startingYear) * 12 + s.month

        // 2. opening lawsuit trigger — v8: G.pendingLawsuitMonth check
        if let lawMonth = s.pendingLawsuitMonth, totalMonths >= lawMonth {
            s.pendingLawsuitMonth = nil
            s.decision = .event(EventDeck.openingLawsuit())
            s.paused = true
            return s
        }

        // 3. traffic — v8: const tr=rawTraffic(); G.currentTraffic=tr
        let tr = Economy.rawTraffic(s)
        s.currentTraffic = tr

        // v8: totalMaxTraffic = sum(s.originalRent>0 ? s.traffic : 40)
        let totalMaxTraffic = s.stores.reduce(0) {
            $0 + ($1.originalRent > 0 ? $1.traffic : 40)
        }
        if Double(tr) < Double(totalMaxTraffic) * 0.3 {
            s.consecutiveLowTrafficMonths += 1
        } else {
            s.consecutiveLowTrafficMonths = max(0, s.consecutiveLowTrafficMonths - 1)
        }

        // v9 Prompt 14 — absolute-floor traffic counter for the memory
        // failure mode. Resets cleanly to 0 on any tick that meets the
        // floor (unlike consecutiveLowTrafficMonths above, which
        // slow-decrements) — "the mall forgot itself" is sustained
        // neglect, and one busy month is a reset, not a partial credit.
        if tr < FailureTuning.trafficFloor {
            s.consecutiveMonthsBelowTrafficFloor += 1
        } else {
            s.consecutiveMonthsBelowTrafficFloor = 0
        }

        // 4. store updates — v8: G.stores.forEach(s => ...)

        // v9 Prompt 9 Phase A — pre-scan the closure set for anchor-cascade
        // context. A closure fires this tick when the pre-loop store has
        // tier != vacant, wing not closed, and closing || leaving already
        // true (set by last tick's hardship / lease logic). The pre-scan
        // gives each vacateSlot call the list of OTHER tenant names closing
        // alongside it so .anchorDeparture can record coincident names.
        let closuresThisTick: [String] = s.stores.compactMap { store in
            guard store.tier != .vacant else { return nil }
            guard !Mall.isWingClosed(store.wing, in: s) else { return nil }
            guard store.closing || store.leaving else { return nil }
            return store.name
        }

        for i in s.stores.indices {
            if s.stores[i].tier == .vacant {
                s.stores[i].monthsVacant += 1
                continue
            }
            s.stores[i].monthsOccupied += 1
            if Mall.isWingClosed(s.stores[i].wing, in: s) { continue }

            // v8: s.stores[i] = vacant(...) — inline vacate on closing/leaving.
            // v9: routed through TenantLifecycle.vacateSlot so both paths also
            // spawn a memorial boardedStorefront artifact. Mechanics unchanged —
            // TenantLifecycle does the same Store.vacant(...) transition inside
            // and appends to state.artifacts.
            // v9 Prompt 9 Phase A — pass the coincident-closure names from the
            // pre-scan above (minus self) so .anchorDeparture can narrate the
            // cascade.
            if s.stores[i].closing {
                let others = closuresThisTick.filter { $0 != s.stores[i].name }
                s = TenantLifecycle.vacateSlot(
                    storeIndex: i, state: s, coincidentClosureNames: others)
                continue
            }
            if s.stores[i].leaving {
                let others = closuresThisTick.filter { $0 != s.stores[i].name }
                s = TenantLifecycle.vacateSlot(
                    storeIndex: i, state: s, coincidentClosureNames: others)
                continue
            }

            if s.stores[i].lease > 0 { s.stores[i].lease -= 1 }

            // v9 Prompt 17 — immuneToTrafficClosure tenants (specialty
            // tier + kiosk holdouts) skip the traffic-based hardship /
            // lease-non-renewal paths entirely. They pay rent on a long
            // lease and just... stay. Hardship still decays on reset so
            // a specialty that somehow got hardship from another path
            // doesn't accumulate.
            let immune = s.stores[i].immuneToTrafficClosure

            // hardship based on traffic against (thresh*2.2), scaled by rent multiplier
            var threshold = Double(s.stores[i].threshold) * 2.2
            if s.stores[i].rentMultiplier > 1.2 { threshold *= 1.2 }
            // v9 Prompt 10 Phase A — wing traffic multiplier. In-wing
            // non-anchor tenants see reduced effective traffic (0.75×)
            // after the wing's anchor has departed. Scoped to hardship
            // calc so the mall-wide tr / rent / visitor motion stay
            // honest; only the struggling-neighbor calculus reflects
            // that one wing has been gutted.
            let wingMult = s.wingTrafficMultipliers[s.stores[i].wing] ?? 1.0
            let effectiveTr = Double(tr) * wingMult
            if !immune {
                if effectiveTr < threshold {
                    s.stores[i].hardship += 1
                    if s.stores[i].hardship >= 4 { s.stores[i].closing = true }
                } else {
                    s.stores[i].hardship = max(0, s.stores[i].hardship - 1)
                }
            } else {
                // Immune: hardship still decays but never accumulates.
                s.stores[i].hardship = max(0, s.stores[i].hardship - 1)
            }

            // lease expiry: traffic-pressured non-renewal or spontaneous leave, else renew 12mo
            // v9 Prompt 17 — immune tenants auto-renew their lease at
            // their original lease length so specialty leases stay long
            // (3-5 years per the catalog) without drifting down toward
            // 12 months on renewal.
            if s.stores[i].lease == 0 && !s.stores[i].closing && !s.stores[i].leaving {
                if immune {
                    // Re-up at the tenant's original lease length. Lease
                    // field is the only info we have about intended
                    // term; use the catalog target's lease if findable,
                    // else a conservative 36 months.
                    s.stores[i].lease = 36
                } else {
                    let pressured = Double(tr) < Double(s.stores[i].threshold) * 3.0
                    if pressured && rng.chance(0.6) {
                        s.stores[i].leaving = true
                    } else if rng.chance(0.3) {
                        s.stores[i].leaving = true
                    } else {
                        s.stores[i].lease = 12
                    }
                }
            }
        }

        // 4.5 anchor cascade — v9 Prompt 10 Phase A.
        // For each wing with a pending hardship cascade, bump +1 hardship
        // on every in-wing non-anchor non-vacant tenant and decrement the
        // counter. Runs AFTER the main store loop so the loop's closing-
        // detection doesn't re-fire within the same tick — cascade-
        // induced closings trip on the NEXT tick, reinforcing the staggered
        // "the wing is unraveling" cadence over 3 months.
        for wing in Wing.allCases {
            let remaining = s.pendingWingHardshipMonths[wing] ?? 0
            guard remaining > 0 else { continue }
            for i in s.stores.indices {
                let store = s.stores[i]
                guard store.wing == wing,
                      store.tier != .vacant,
                      store.tier != .anchor else { continue }
                s.stores[i].hardship += 1
                if s.stores[i].hardship >= 4 {
                    s.stores[i].closing = true
                }
            }
            s.pendingWingHardshipMonths[wing] = remaining - 1
        }

        // 5. artifact decay — v8: G.decorations.forEach(...)
        // v9 Prompt 3 — loop now iterates state.artifacts (unified model).
        // Only artifacts with a catalog cost > 0 (player-placeable, formerly
        // Decorations) are subject to decay. Ambient / memorial types
        // (boardedStorefront, sealedEntrance, emptyFoodCourt, custom) are
        // frozen — condition is set at creation and doesn't advance here.
        // v9 Prompt 13 — memory weight decay. Applies to ALL artifacts
        // (not just player-placeable ones — memorial artifacts decay too
        // if nobody thinks about them). Counter is incremented every
        // tick; once it crosses memoryDecayMonths (6), memoryWeight
        // multiplicatively decays by memoryDecayRatePerMonth (5%) per
        // tick. GameViewModel.recordThoughtFired resets the counter to 0
        // so any visitor thought on an artifact refreshes its "lived-in"
        // status. Decay is multiplicative so weight asymptotes toward
        // zero but never reaches exactly zero until reset.
        for i in s.artifacts.indices {
            s.artifacts[i].monthsSinceLastThought += 1
            if s.artifacts[i].monthsSinceLastThought >= Scoring.ScoringTuning.memoryDecayMonths {
                let retention = 1.0 - Scoring.ScoringTuning.memoryDecayRatePerMonth
                s.artifacts[i].memoryWeight = max(0,
                    s.artifacts[i].memoryWeight * retention)
            }
        }

        let janitorialMult = s.activeStaff.janitorial ? 0.5 : 1.0
        for i in s.artifacts.indices {
            guard ArtifactCatalog.info(s.artifacts[i].type).cost > 0 else { continue }

            s.artifacts[i].monthsAtCondition += 1
            // v9 Prompt 21 Fix 2 — constants pulled from ArtifactTuning
            // (halved from the pre-Prompt-21 inline literals).
            let decayChance = (ArtifactTuning.decayBaseProbability
                + Double(s.artifacts[i].condition) * ArtifactTuning.decayConditionStep)
                * janitorialMult

            if s.artifacts[i].condition < 4 && rng.chance(decayChance) {
                // v9 Prompt 9 Phase A — capture from-condition for the ledger
                // entry, increment, then emit. One entry per increment
                // (0→1, 1→2, 2→3, 3→4).
                let fromCondition = s.artifacts[i].condition
                s.artifacts[i].condition += 1
                s.artifacts[i].monthsAtCondition = 0
                s.ledger.append(.decayTransition(
                    artifactId: s.artifacts[i].id,
                    name: s.artifacts[i].name,
                    type: s.artifacts[i].type,
                    fromCondition: fromCondition,
                    toCondition: s.artifacts[i].condition,
                    year: s.year,
                    month: s.month
                ))
                if s.artifacts[i].condition >= 4
                    && !s.artifacts[i].hazard
                    && rng.chance(ArtifactTuning.hazardOnDecayToRuinChance) {
                    s.artifacts[i].hazard = true
                }
            } else if s.artifacts[i].condition >= 4
                        && !s.artifacts[i].hazard
                        && rng.chance(ArtifactTuning.hazardAtRuinChance) {
                s.artifacts[i].hazard = true
            }
        }

        // 6. economics — v8: G.cash += r+ad+pr-ops-st-pc-fines
        //
        // v9 Prompt 15 Phase 1 — compute per-source breakdowns so the
        // scene can render floating +$N / -$N indicators at each line
        // item. rentByStore emits per storefront; hazardFinesByArtifact
        // per artifact; ops/staff/promo-cost are aggregated into a
        // single mall-wide operating-cost event (no single source to
        // attach to).
        let rentItems = Economy.rentByStore(s)
        let fineItems = Economy.hazardFinesByArtifact(s)
        let r     = rentItems.reduce(0) { $0 + $1.amount }
        let fines = fineItems.reduce(0) { $0 + $1.amount }
        let ad    = Economy.adRevenue(s)
        let pr    = Economy.promoRevenue(s)
        let ops   = Economy.operatingCost(s)
        let st    = Economy.staffCost(s)
        let pc    = Economy.promoCost(s)
        s.hazardFines = fines
        s.cash += r + ad + pr - ops - st - pc - fines
        if s.cash < 0 {
            s.debt += abs(s.cash)
            s.cash = 0
        }

        // v9 Prompt 21 Fix 4 — first-crossing bankruptcy warning. Fires
        // exactly once per run the first tick debt reaches the warning
        // threshold ($20,000). bankruptcyWarningShown is a one-way latch;
        // bankruptcyWarningPending drives the MallView card mount. The
        // card's Continue clears Pending but leaves Shown set, so the
        // warning does not re-fire if debt bounces across the threshold
        // after a pay-down.
        if s.debt >= FailureTuning.bankruptcyWarningThreshold
            && !s.bankruptcyWarningShown {
            s.bankruptcyWarningShown = true
            s.bankruptcyWarningPending = true
        }

        // Emit economics events for scene rendering. Replaces
        // lastTickEconomicsEvents — prior tick's events are discarded.
        var events: [EconomicsEvent] = []
        events.reserveCapacity(rentItems.count + fineItems.count + 1)
        for item in rentItems {
            events.append(.rentCollected(storeId: item.storeId,
                                          amount: item.amount))
        }
        for item in fineItems {
            events.append(.hazardFine(artifactId: item.artifactId,
                                       amount: item.amount))
        }
        let opsAggregate = ops + st + pc
        if opsAggregate > 0 {
            events.append(.operatingCost(amount: opsAggregate))
        }
        s.lastTickEconomicsEvents = events

        // 7. score — v8: const ms=monthlyScore(); G.score+=ms
        let ms = Scoring.monthlyScore(s)
        s.lastMonthlyScore = ms
        s.score += ms
        s.scoreHistory.append(ms)

        // 8. promo decay — v8: activePromos.map(remaining-1).filter(remaining>0)
        s.activePromos = s.activePromos.compactMap { p in
            var p = p
            p.remaining -= 1
            return p.remaining > 0 ? p : nil
        }
        if s.gangMonths > 0 { s.gangMonths -= 1 }

        // 9. threat + warnings — v8: G.threatMeter=calculateThreat(); refreshWarnings()
        s.threatMeter = Threat.calculate(s)
        s = Warnings.refresh(s)

        // 9.25 environmental state dwell — v9 Prompt 8. Counter drives the
        // ghostMall transition (monthsInDeadState >= 60). Increment while in
        // .dead; reset on any recovery so a mall that briefly drops then
        // recovers doesn't ghost-transition from leftover dwell.
        if Mall.state(s) == .dead {
            s.monthsInDeadState += 1
        } else {
            s.monthsInDeadState = 0
        }

        // 9.5 entrance sealing — v9 iPad-port addition. When mall state is
        // struggling or worse, one still-open corner entrance has a monthly
        // chance of getting boarded up. Not reversible.
        //
        // v9 Prompt 6.5 — was a north/south coin flip across two doors. Now
        // picks uniformly at random from currently-open corners (open meaning
        // not sealed AND wing not closed). Per-tick probability is unchanged;
        // with four candidates instead of two, each corner's per-tick seal
        // rate drops.
        let sealProbability: Double
        switch Mall.state(s) {
        case .struggling: sealProbability = 0.05
        case .dying:      sealProbability = 0.10
        case .dead:       sealProbability = 0.15
        case .thriving, .fading: sealProbability = 0
        }
        if sealProbability > 0 && rng.chance(sealProbability) {
            let open = Array(Mall.openEntrances(in: s))
                .sorted { $0.rawValue < $1.rawValue }   // deterministic ordering for RNG
            if !open.isEmpty {
                let pickIndex = rng.int(in: 0..<open.count)
                s.sealedEntrances.insert(open[pickIndex])
            }
        }

        // 10. maybe a decision (tenant offer or flavor event) — v8: maybeDecision()
        s = EventDeck.maybeDecision(s, rng: &rng)

        // 10.5 environmental transition — v9 Prompt 9 Phase A.
        // Compare the post-tick EnvironmentState against prevEnv captured at
        // top. Emit one .envTransition entry if the mall crossed a band.
        // Placed BEFORE the bankruptcy short-circuit so the ledger still
        // captures a state change that happened in the same tick the mall
        // went under.
        let newEnv = EnvironmentState.from(s)
        if newEnv != prevEnv {
            s.ledger.append(.envTransition(
                from: prevEnv, to: newEnv,
                year: s.year, month: s.month
            ))
        }

        // 11. bankruptcy — v8: if(G.debt>=DEBT_CEIL) endGame('bankruptcy')
        if s.debt >= GameConstants.debtCeiling {
            s.gameover = true
            s.gameOverReason = .bankruptcy
            return s
        }

        // 12. memory failure — v9 Prompt 14. The mall forgot itself.
        // Checked after bankruptcy so economic collapse takes precedence
        // (a mall going broke IS a failure; no need to also assess
        // memorial neglect). Three AND-ed conditions in FailureMode —
        // see that file for the semantics.
        if FailureMode.shouldForget(s) {
            s.gameover = true
            s.gameOverReason = .forgotten
            return s
        }

        return s
    }
}
