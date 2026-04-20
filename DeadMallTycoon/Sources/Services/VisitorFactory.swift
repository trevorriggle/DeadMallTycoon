import Foundation

// v8: spawnVisitor(), pickTarget(), initVisitors(), updateVisitorPositions() target-count logic.
// Visitor motion itself belongs to the SpriteKit scene's update loop — this service is
// only responsible for *creating* a visitor with a sensible initial target.
enum VisitorFactory {

    // v8: spawnVisitor()
    static func spawn(state: GameState, rng: inout some RandomNumberGenerator) -> Visitor {
        let mallState = Mall.state(state)
        let personalityKey = PersonalityPicker.weightedPick(state: mallState, rng: &rng)
        let personality = Personalities.all[personalityKey] ?? Personalities.all["Casual Browser"]!
        let names = Personalities.names(for: personality.type)
        let name = rng.pick(names) ?? "Visitor"
        let side: String = rng.chance(0.5) ? "left" : "right"
        let age = personality.ageRange.lowerBound + rng.int(in: 0..<(personality.ageRange.count))

        var v = Visitor(
            id: UUID(),
            name: name,
            personality: personalityKey,
            type: personality.type,
            color: personality.color,
            headColor: personality.headColor,
            age: age,
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
