import Foundation

// v8: buildEvents(), triggerOpeningLawsuit(), maybeDecision(), and the per-event
// accept/decline closures (ported here as a switch on FlavorEventKind).
enum EventDeck {

    // v8: triggerOpeningLawsuit()
    static func openingLawsuit() -> FlavorEvent {
        FlavorEvent(
            kind: .openingLawsuit(settleCost: 1500),
            name: "Inherited Lawsuit",
            description: "A letter from the city arrives. The previous owner left unresolved code violations from three years ago. They want to settle quietly, or drag you into court.",
            acceptLabel: "Settle ($1,500)",
            declineLabel: "Fight it (50/50)"
        )
    }

    // v8: buildEvents()
    static func buildDeck(_ state: GameState) -> [FlavorEvent] {
        let cashNow = state.cash
        let hasSecurity = state.activeStaff.security
        let closedWings = Mall.closedWingsCount(state)
        var events: [FlavorEvent] = []

        // Burst Pipes — always present
        let hadHazardWarning = state.warnings.contains {
            $0.key.hasPrefix("hazard_") || $0.key.hasPrefix("decay_")
        }
        let pipeRepair = max(4000, Int(Double(cashNow) * 0.25))
        let pipeDesc = hadHazardWarning
            ? "A pipe burst overnight. The Watch List had been warning about decay."
            : "A pipe burst overnight. No one saw this coming."
        events.append(FlavorEvent(
            kind: .burstPipes(repairCost: pipeRepair),
            name: "Burst Pipes",
            description: pipeDesc,
            acceptLabel: "Repair ($\(pipeRepair))",
            declineLabel: "Leave It"
        ))

        // Vandalism — only with no security and at least one closed wing OR extended low traffic
        if !hasSecurity && (closedWings > 0 || state.consecutiveLowTrafficMonths > 2) {
            let hadWingWarning = state.warnings.contains { $0.key == "wing_crime" }
            let desc = (hadWingWarning
                ? "As the Watch List predicted, trespassers have hit the sealed wing."
                : "The sealed wing attracted trespassers.") + " Graffiti, broken glass."
            events.append(FlavorEvent(
                kind: .vandalism(cleanupCost: 3500),
                name: "Vandalism in Closed Wing",
                description: desc,
                acceptLabel: "Clean Up ($3,500)",
                declineLabel: "Ignore"
            ))
        }

        // Gang Activity — only with no security
        if !hasSecurity {
            events.append(FlavorEvent(
                kind: .gangActivity(securityCost: 4000),
                name: "Gang Activity",
                description: "Police report gang activity in the parking lot.",
                acceptLabel: "Hire extra security ($4,000)",
                declineLabel: "Ignore"
            ))
        }

        // City Inspection — only after 3+ months of low traffic
        if state.consecutiveLowTrafficMonths >= 3 {
            let hadTrafficWarning = state.warnings.contains {
                $0.key.hasPrefix("low_traffic")
            }
            let desc = hadTrafficWarning
                ? "The inspection you were warned about has arrived."
                : "Low foot traffic flagged the mall for inspection."
            events.append(FlavorEvent(
                kind: .cityInspection(cooperateCost: 2500),
                name: "City Inspection",
                description: desc,
                acceptLabel: "Cooperate ($2,500)",
                declineLabel: "Stonewall"
            ))
        }

        // Code Violations — always present
        events.append(FlavorEvent(
            kind: .codeViolations(payCost: 5000),
            name: "Code Violations",
            description: "City inspector cites violations.",
            acceptLabel: "Pay ($5,000)",
            declineLabel: "Appeal"
        ))

        // HVAC Failure — always present
        let hvacRepair = max(3500, Int(Double(cashNow) * 0.2))
        events.append(FlavorEvent(
            kind: .hvacFailure(repairCost: hvacRepair),
            name: "HVAC Failure",
            description: "Main AC unit is dead.",
            acceptLabel: "Repair ($\(hvacRepair))",
            declineLabel: "Endure"
        ))

        return events
    }

    // v8: maybeDecision()
    static func maybeDecision(_ state: GameState, rng: inout some RandomNumberGenerator) -> GameState {
        var s = state
        if s.decision != nil { return s }
        let totalMonths = (s.year - GameConstants.startingYear) * 12 + s.month
        let vacCount = Mall.openStores(s).filter { $0.tier == .vacant }.count
        let mallState = Mall.state(s)
        let stateOfferMult: Double = {
            switch mallState {
            case .thriving:   return 1.2
            case .fading:     return 1.0
            case .struggling: return 0.6
            case .dying:      return 0.35
            case .dead:       return 0.15
            }
        }()

        if vacCount > 0 && rng.chance(0.09 * stateOfferMult) {
            let pool = Tenants.offerPool(for: mallState)
            if let offer = rng.pick(pool) {
                s.decision = .tenant(offer)
                s.paused = true
                return s
            }
        }

        if totalMonths >= 6 && rng.chance(s.threatMeter * 0.35) {
            let events = buildDeck(s)
            if let ev = rng.pick(events) {
                s.decision = .event(ev)
                s.paused = true
                return s
            }
        }

        return s
    }

    // v8: event fnA / fnD closures
    static func apply(_ event: FlavorEvent, choice: EventChoice,
                      state: GameState,
                      rng: inout some RandomNumberGenerator) -> GameState {
        var s = state
        switch (event.kind, choice) {

        case (.openingLawsuit(let cost), .accept):
            s.cash -= cost
            // v9 patch — quiet info toast confirming the settlement landed.
            s.toasts.append(Toast(
                title: "CASE SETTLED",
                subtitle: "The city took the $\(cost) and dropped it.",
                style: .info
            ))

        case (.openingLawsuit, .decline):
            // v9 patch — surface the RNG outcome so the player knows
            // whether the gamble paid off. Without this, a favorable roll
            // (no charge) was completely silent.
            if rng.chance(0.5) {
                s.cash -= 5000
                s.toasts.append(Toast(
                    title: "THE COURT RULED AGAINST YOU",
                    subtitle: "Judgment: $5,000.",
                    style: .loss
                ))
            } else {
                s.toasts.append(Toast(
                    title: "THE CASE WAS DROPPED",
                    subtitle: "No charges. Move on.",
                    style: .victory
                ))
            }

        case (.burstPipes(let cost), .accept):
            s.cash -= cost

        case (.burstPipes, .decline):
            // v8: south-wing stores with hw<3, first 4, hw+=2
            var hit = 0
            for i in s.stores.indices where hit < 4 {
                if s.stores[i].wing == .south && s.stores[i].hardship < 3 {
                    s.stores[i].hardship += 2
                    hit += 1
                }
            }
            // v8: decorations with y>300 and condition<4 advance
            // v9 Prompt 3 — iterate state.artifacts; ambient types have nil y
            // and are skipped naturally by the optional-y binding.
            for i in s.artifacts.indices {
                guard let y = s.artifacts[i].y, y > 300,
                      s.artifacts[i].condition < 4 else { continue }
                s.artifacts[i].condition += 1
            }

        case (.vandalism(let cost), .accept):
            s.cash -= cost

        case (.vandalism, .decline):
            // v8: every decoration with condition<4 has 40% chance to advance
            // v9 Prompt 3 — iterate placeable artifacts only (cost > 0 filter).
            for i in s.artifacts.indices {
                guard s.artifacts[i].condition < 4,
                      ArtifactCatalog.info(s.artifacts[i].type).cost > 0 else { continue }
                if rng.chance(0.4) { s.artifacts[i].condition += 1 }
            }

        case (.gangActivity(let cost), .accept):
            s.cash -= cost

        case (.gangActivity, .decline):
            s.gangMonths = 3

        case (.cityInspection(let cost), .accept):
            s.cash -= cost

        case (.cityInspection, .decline):
            // v8: first 2 decorations with condition<4 get tagged hazard
            // v9 Prompt 3 — iterate placeable artifacts only (cost > 0 filter).
            var tagged = 0
            for i in s.artifacts.indices where tagged < 2 {
                if s.artifacts[i].condition < 4
                    && ArtifactCatalog.info(s.artifacts[i].type).cost > 0 {
                    s.artifacts[i].hazard = true
                    tagged += 1
                }
            }

        case (.codeViolations(let cost), .accept):
            s.cash -= cost

        case (.codeViolations, .decline):
            if rng.chance(0.5) { s.cash -= 9000 }

        case (.hvacFailure(let cost), .accept):
            s.cash -= cost

        case (.hvacFailure, .decline):
            // v8: first 3 stores with hw<3 have hw++
            var hit = 0
            for i in s.stores.indices where hit < 3 {
                if s.stores[i].hardship < 3 {
                    s.stores[i].hardship += 1
                    hit += 1
                }
            }
        }

        return s
    }
}
