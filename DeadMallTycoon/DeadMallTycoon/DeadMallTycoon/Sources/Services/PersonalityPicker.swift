import Foundation

// v8: weightedPersonality() + pickMemory().
// v9 Prompt 4 Phase 2 — pickMemory is now wrapped by pickThought which
// returns a Thought (text + optional artifactId). The legacy pickMemory
// signature is preserved as a thin text-only wrapper for any caller that
// still only wants a String.
enum PersonalityPicker {

    // v8: weightedPersonality() + v9 Ghost Mall gate.
    static func weightedPick(state: MallState, year: Int,
                             rng: inout some RandomNumberGenerator) -> String {
        let useGhost = Personalities.useGhostWeights(year: year, state: state)
        let table = useGhost
            ? (Personalities.weightsGhost[state] ?? Personalities.weights[state] ?? [])
            : (Personalities.weights[state] ?? [])
        let total = table.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return "Casual Browser" }
        var r = rng.double(in: 0..<Double(total))
        for (name, w) in table {
            r -= Double(w)
            if r <= 0 { return name }
        }
        return "Casual Browser"
    }

    // v9 Prompt 4 Phase 2 — returns a Thought tagged with the artifact it
    // references, or nil artifactId for generic personality-pool thoughts.
    //
    // Proximity gate: callers pass the visitor's current CSS position.
    // Artifacts within ThoughtTuning.artifactProximityRadius are "nearby".
    // Artifacts without x/y (ambient types) never qualify.
    //
    // Mixing rule: even with a nearby artifact, there's a `genericFallbackChance`
    // the visitor surfaces a generic personality thought instead — so the
    // mall doesn't feel like it only ever narrates its objects.
    private static let genericFallbackChance: Double = 0.25

    static func pickThought(for visitor: Visitor,
                             at visitorPos: (x: Double, y: Double),
                             in state: GameState,
                             rng: inout some RandomNumberGenerator) -> Thought {
        // 1. Find nearby artifacts.
        let radiusSq = ThoughtTuning.artifactProximityRadius
                      * ThoughtTuning.artifactProximityRadius
        let nearby = state.artifacts.compactMap { a -> (Artifact, Double)? in
            guard let ax = a.x, let ay = a.y else { return nil }
            let dx = ax - visitorPos.x
            let dy = ay - visitorPos.y
            let d2 = dx*dx + dy*dy
            guard d2 <= radiusSq else { return nil }
            return (a, d2)
        }

        // 2. If a nearby artifact wins the coin flip, pull from its pool.
        if !nearby.isEmpty, !rng.chance(genericFallbackChance) {
            let closest = nearby.min { $0.1 < $1.1 }!.0
            if !closest.thoughtTriggers.isEmpty,
               let text = rng.pick(closest.thoughtTriggers) {
                return Thought(text: text, artifactId: closest.id)
            }
        }

        // 3. Fallback — generic personality-state pool.
        let text = genericPoolText(for: visitor, in: state, rng: &rng)
        return Thought(text: text, artifactId: nil)
    }

    // v8: pickMemory() — legacy text-only helper. Discards artifactId.
    // v9 Prompt 4 — retained for non-spatial callers (e.g. callers that
    // don't have the visitor's current position handy). New code should
    // prefer pickThought.
    static func pickMemory(for visitor: Visitor, in state: GameState,
                           rng: inout some RandomNumberGenerator) -> String {
        genericPoolText(for: visitor, in: state, rng: &rng)
    }

    private static func genericPoolText(for visitor: Visitor, in state: GameState,
                                         rng: inout some RandomNumberGenerator) -> String {
        let mallState = Mall.state(state)
        guard let p = Personalities.all[visitor.personality],
              let pool = p.thoughts[mallState],
              !pool.isEmpty else {
            return "\"...\""
        }
        return rng.pick(pool) ?? "\"...\""
    }
}
