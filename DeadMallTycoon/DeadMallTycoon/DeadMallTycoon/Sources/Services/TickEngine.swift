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

            if s.stores[i].closing {
                s.stores[i] = Store.vacant(id: s.stores[i].id, at: s.stores[i].position)
                continue
            }
            if s.stores[i].leaving {
                s.stores[i] = Store.vacant(id: s.stores[i].id, at: s.stores[i].position)
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

        // 5. decoration decay — v8: G.decorations.forEach(...)
        let janitorialMult = s.activeStaff.janitorial ? 0.5 : 1.0
        for i in s.decorations.indices {
            s.decorations[i].monthsAtCondition += 1
            let decayChance = (0.02 + Double(s.decorations[i].condition) * 0.01) * janitorialMult

            if s.decorations[i].condition < 4 && rng.chance(decayChance) {
                s.decorations[i].condition += 1
                s.decorations[i].monthsAtCondition = 0
                if s.decorations[i].condition >= 4
                    && !s.decorations[i].hazard
                    && rng.chance(0.4) {
                    s.decorations[i].hazard = true
                }
            } else if s.decorations[i].condition >= 4
                        && !s.decorations[i].hazard
                        && rng.chance(0.15) {
                s.decorations[i].hazard = true
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
