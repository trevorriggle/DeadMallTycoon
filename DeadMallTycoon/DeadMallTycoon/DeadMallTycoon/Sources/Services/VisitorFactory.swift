import Foundation

// v8: spawnVisitor(), pickTarget(), initVisitors(), updateVisitorPositions() target-count logic.
// Visitor motion itself belongs to the SpriteKit scene's update loop — this service is
// only responsible for *creating* a visitor with a sensible initial target.
enum VisitorFactory {

    // v8: spawnVisitor() — v9 Ghost Mall kicks in automatically via the year passed
    // into PersonalityPicker.weightedPick.
    // v9 Prompt 4 Phase 1 — identity (firstName, lastName, ageCohort) and
    // narrative state (mood, activity, destinationIntent) populated here.
    // The old Personalities.names(for:) pool is superseded by the
    // period-appropriate VisitorNames pool; the type-specific name table
    // is no longer consulted (the visitor's name is now cohort-driven, not
    // personality-driven).
    static func spawn(state: GameState, rng: inout some RandomNumberGenerator) -> Visitor {
        let mallState = Mall.state(state)
        let personalityKey = PersonalityPicker.weightedPick(state: mallState,
                                                             year: state.year,
                                                             rng: &rng)
        let personality = Personalities.all[personalityKey] ?? Personalities.all["Casual Browser"]!
        let side: String = rng.chance(0.5) ? "left" : "right"
        let age = personality.ageRange.lowerBound + rng.int(in: 0..<(personality.ageRange.count))

        // v9 Prompt 4 Phase 1 — identity.
        let firstName = rng.pick(VisitorNames.firstNames) ?? "Visitor"
        let lastName  = rng.pick(VisitorNames.lastNames)  ?? "Smith"
        let cohort = AgeCohort.from(age: age)
        let mood       = rng.pick(VisitorMood.allCases)     ?? .curious
        let activity   = rng.pick(VisitorActivity.allCases) ?? .wandering
        let destination = pickDestination(rng: &rng)

        var v = Visitor(
            id: UUID(),
            firstName: firstName,
            lastName: lastName,
            ageCohort: cohort,
            mood: mood,
            activity: activity,
            destinationIntent: destination,
            personality: personalityKey,
            type: personality.type,
            color: personality.color,
            headColor: personality.headColor,
            age: age,
            tenantIdAffinity: nil,
            x: side == "left" ? -20 : 1200,
            y: 220 + rng.double(in: 0..<60),
            vx: 0, vy: 0,
            speed: 0.35 + rng.double(in: 0..<0.25),
            target: nil,
            state: .entering,
            dwellTimer: 0,
            memory: "",
            targetType: ""
        )
        pickTarget(for: &v, in: state, rng: &rng)
        return v
    }

    // v9 Prompt 4 Phase 1 — plausible destination intent at spawn.
    // `.store(slotId:)` is omitted here (coupling spawn to store layout is
    // unnecessary; "a store" is presented abstractly in the panel).
    private static func pickDestination(rng: inout some RandomNumberGenerator) -> DestinationIntent {
        let roll = rng.int(in: 0..<10)
        switch roll {
        case 0, 1, 2: return .noDestination    // 30%
        case 3, 4:    return .fountain          // 20%
        case 5:       return .foodCourt         // 10%
        case 6:       return .directory         // 10%
        case 7, 8:    return .nearestExit       // 20%
        default:      return .noDestination     // remainder
        }
    }

    // v8: pickTarget()
    static func pickTarget(for v: inout Visitor, in state: GameState,
                           rng: inout some RandomNumberGenerator) {
        let personality = Personalities.all[v.personality] ?? Personalities.all["Casual Browser"]!
        let interested = state.stores.filter {
            $0.tier != .vacant && !Mall.isWingClosed($0.wing, in: state)
            && personality.preferredStores.contains($0.name)
        }
        if !interested.isEmpty, rng.chance(0.7), let store = rng.pick(interested) {
            let ty = store.wing == .north
                ? store.position.y + store.position.h + 15
                : store.position.y - 15
            v.target = VisitorTarget(x: store.position.x + store.position.w / 2,
                                     y: ty, storeId: store.id)
            v.targetType = "store"
        } else {
            v.target = VisitorTarget(
                x: 50 + rng.double(in: 0..<1100),
                y: 210 + rng.double(in: 0..<70),
                storeId: nil
            )
            v.targetType = "wander"
        }
    }

    // v8: updateVisitorPositions() — just the "target count" calculation used to decide
    // whether to spawn another visitor. Motion itself lives in the scene's frame loop.
    static func targetVisitorCount(_ state: GameState) -> Int {
        var target: Int = {
            switch Mall.state(state) {
            case .thriving:   return 22
            case .fading:     return 17
            case .struggling: return 13
            case .dying:      return 8
            case .dead:       return 4
            }
        }()
        for p in state.activePromos {
            switch p.effect {
            case .traffic: target = Int(Double(target) * 1.25)
            case .sale:    target = Int(Double(target) * 1.15)
            case .holiday: target = Int(Double(target) * 1.20)
            case .oneshot: target = Int(Double(target) * 1.40)
            case .flea:    target = Int(Double(target) * 1.10)
            case .ghost:   break
            }
        }
        if state.activeStaff.marketing { target = Int(Double(target) * 1.05) }
        if state.gangMonths > 0        { target = Int(Double(target) * 0.65) }
        return target
    }
}
