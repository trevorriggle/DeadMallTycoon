import Foundation

// v8: tick()
// The heart. Pure function: takes a GameState and an RNG, returns a new GameState.
// No timers, no rendering, no global mutation. All randomness flows through `rng`
// so tests pin behavior with a seeded generator.
enum TickEngine {

    static func tick(_ state: GameState, rng: inout some RandomNumberGenerator) -> GameState {
        var s = state
        if s.gameover || s.paused || !s.started { return s }

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

        // 4. store updates — v8: G.stores.forEach(s => ...)
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
            if s.stores[i].closing {
                s = TenantLifecycle.vacateSlot(storeIndex: i, state: s)
                continue
            }
            if s.stores[i].leaving {
                s = TenantLifecycle.vacateSlot(storeIndex: i, state: s)
                continue
            }

            if s.stores[i].lease > 0 { s.stores[i].lease -= 1 }

            // hardship based on traffic against (thresh*2.2), scaled by rent multiplier
            var threshold = Double(s.stores[i].threshold) * 2.2
            if s.stores[i].rentMultiplier > 1.2 { threshold *= 1.2 }
            if Double(tr) < threshold {
                s.stores[i].hardship += 1
                if s.stores[i].hardship >= 4 { s.stores[i].closing = true }
            } else {
                s.stores[i].hardship = max(0, s.stores[i].hardship - 1)
            }

            // lease expiry: traffic-pressured non-renewal or spontaneous leave, else renew 12mo
            if s.stores[i].lease == 0 && !s.stores[i].closing && !s.stores[i].leaving {
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

        // 5. artifact decay — v8: G.decorations.forEach(...)
        // v9 Prompt 3 — loop now iterates state.artifacts (unified model).
        // Only artifacts with a catalog cost > 0 (player-placeable, formerly
        // Decorations) are subject to decay. Ambient / memorial types
        // (boardedStorefront, sealedEntrance, emptyFoodCourt, custom) are
        // frozen — condition is set at creation and doesn't advance here.
        let janitorialMult = s.activeStaff.janitorial ? 0.5 : 1.0
        for i in s.artifacts.indices {
            guard ArtifactCatalog.info(s.artifacts[i].type).cost > 0 else { continue }

            s.artifacts[i].monthsAtCondition += 1
            let decayChance = (0.02 + Double(s.artifacts[i].condition) * 0.01) * janitorialMult

            if s.artifacts[i].condition < 4 && rng.chance(decayChance) {
                s.artifacts[i].condition += 1
                s.artifacts[i].monthsAtCondition = 0
                if s.artifacts[i].condition >= 4
                    && !s.artifacts[i].hazard
                    && rng.chance(0.4) {
                    s.artifacts[i].hazard = true
                }
            } else if s.artifacts[i].condition >= 4
                        && !s.artifacts[i].hazard
                        && rng.chance(0.15) {
                s.artifacts[i].hazard = true
            }
        }

        // 6. economics — v8: G.cash += r+ad+pr-ops-st-pc-fines
        let r  = Economy.rent(s)
        let ad = Economy.adRevenue(s)
        let pr = Economy.promoRevenue(s)
        let ops = Economy.operatingCost(s)
        let st  = Economy.staffCost(s)
        let pc  = Economy.promoCost(s)
        let fines = Economy.hazardFines(s)
        s.hazardFines = fines
        s.cash += r + ad + pr - ops - st - pc - fines
        if s.cash < 0 {
            s.debt += abs(s.cash)
            s.cash = 0
        }

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

        // 11. bankruptcy — v8: if(G.debt>=DEBT_CEIL) endGame('bankruptcy')
        if s.debt >= GameConstants.debtCeiling {
            s.gameover = true
            return s
        }

        return s
    }
}
