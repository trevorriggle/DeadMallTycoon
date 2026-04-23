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
    // v9 Prompt 11 rewrite:
    //   - Proximity gate is now the ONLY gate. If any artifact is in
    //     proximity, the visitor thinks about one of them. No coin-flip
    //     fallback. The "generic thoughts become rarer as the mall ages"
    //     property emerges naturally: late-game malls have many more
    //     artifacts (closed storefronts, cascades, displays), so the
    //     proximity match hits more often, and the personality-pool
    //     fallback path runs correspondingly less.
    //   - Among nearby artifacts, weighted-random by memoryWeight (plus
    //     a floor so fresh artifacts still have a chance). Higher-memory
    //     artifacts get picked more often — the mall remembers itself
    //     more as it ages.
    //   - Per-cohort pool access: older visitors see more of each
    //     artifact's thoughtTriggers pool. Originals see 100%; Nostalgics
    //     see the first 60%; Explorers see the first 30%. The narrative
    //     framing: Originals lived through the mall's history and carry
    //     specifics; Explorers are newer and only register surface
    //     observations. Authoring convention: thoughtTriggers ordered
    //     universal → specific so the cohort gate produces nested
    //     subsets with the right flavor.
    //
    // Proximity radius: ThoughtTuning.artifactProximityRadius. Artifacts
    // without x/y (ambient types — boardedStorefront etc.) never qualify.

    static func pickThought(for visitor: Visitor,
                             at visitorPos: (x: Double, y: Double),
                             in state: GameState,
                             rng: inout some RandomNumberGenerator) -> Thought {
        // 1. Nearby artifacts.
        let nearby = nearbyArtifacts(around: visitorPos,
                                      in: state.artifacts)

        // 2. If any nearby artifact has authored thoughts the visitor
        //    can access, pick one (weighted by memory) and return its
        //    cohort-gated pool pick. Otherwise fall through to the
        //    personality × state pool.
        if let tagged = pickArtifactThought(from: nearby,
                                             cohort: visitor.ageCohort,
                                             rng: &rng) {
            return tagged
        }

        // 3. Fallback — personality × state pool. Fires when no
        //    artifact is in proximity OR every in-range artifact has
        //    an empty pool accessible to this cohort.
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

    // MARK: - v9 Prompt 11 helpers

    // Returns the artifacts whose (x, y) sits within
    // ThoughtTuning.artifactProximityRadius of the visitor position.
    // Ambient artifacts (nil x/y) never qualify. Order unspecified.
    static func nearbyArtifacts(around pos: (x: Double, y: Double),
                                 in artifacts: [Artifact]) -> [Artifact] {
        let radiusSq = ThoughtTuning.artifactProximityRadius
                      * ThoughtTuning.artifactProximityRadius
        return artifacts.compactMap { a in
            guard let ax = a.x, let ay = a.y else { return nil }
            let dx = ax - pos.x
            let dy = ay - pos.y
            return (dx*dx + dy*dy) <= radiusSq ? a : nil
        }
    }

    // Weighted-random pick among nearby artifacts (by memoryWeight +
    // floor) → cohort-gated pool subset → random string. Returns nil
    // iff the nearby list is empty OR all accessible pools are empty.
    static func pickArtifactThought(from nearby: [Artifact],
                                     cohort: AgeCohort,
                                     rng: inout some RandomNumberGenerator) -> Thought? {
        guard !nearby.isEmpty else { return nil }

        // Weighted pick. Weight = floor + memoryWeight. Floor ensures
        // fresh artifacts aren't starved at memoryWeight=0.
        let floor = ThoughtTuning.memoryWeightFloor
        let weights = nearby.map { max(0.0, floor + $0.memoryWeight) }
        let total = weights.reduce(0, +)

        let picked: Artifact
        if total <= 0 {
            // All negative/zero somehow — shouldn't happen with the floor,
            // but fall back to uniform.
            picked = rng.pick(nearby) ?? nearby[0]
        } else {
            let draw = rng.double(in: 0..<total)
            var cumulative = 0.0
            var chosen: Artifact?
            for (artifact, weight) in zip(nearby, weights) {
                cumulative += weight
                if draw < cumulative {
                    chosen = artifact
                    break
                }
            }
            picked = chosen ?? nearby.last!
        }

        // Cohort-gated pool subset. Empty accessible pool → fall back.
        let accessible = cohortAccessiblePool(picked.thoughtTriggers,
                                               cohort: cohort)
        guard let text = rng.pick(accessible) else { return nil }
        return Thought(text: text, artifactId: picked.id)
    }

    // Returns the prefix of `pool` that the given cohort can "access."
    // Length = round(pool.count × cohortPoolFraction[cohort]), with a
    // min of 1 so non-empty pools are never gated to zero. Nested:
    // Explorers ⊆ Nostalgics ⊆ Originals (all take the FIRST N strings).
    static func cohortAccessiblePool(_ pool: [String],
                                      cohort: AgeCohort) -> [String] {
        guard !pool.isEmpty else { return [] }
        let fraction = ThoughtTuning.cohortPoolFraction[cohort] ?? 1.0
        let n = max(1, Int((Double(pool.count) * fraction).rounded()))
        return Array(pool.prefix(min(n, pool.count)))
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
