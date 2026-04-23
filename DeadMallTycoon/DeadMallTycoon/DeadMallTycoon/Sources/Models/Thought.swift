import Foundation

// v9 Prompt 4 Phase 2 — thought-to-artifact tagging.
// A thought is text PLUS an optional artifact reference. When a visitor
// passes near an artifact and a thought fires against that artifact's
// pool, artifactId is set. Generic mall-feel thoughts (from the personality
// pool, no specific landmark) leave artifactId nil.
//
// Memory weight accumulation (Phase 3) reads this: non-nil artifactId →
// increment the referenced artifact's weight; nil → no weight accrual.
struct Thought: Equatable {
    let text: String
    let artifactId: Int?
}

// v9 Prompt 4 Phase 2 — tuning constants, co-located.
enum ThoughtTuning {
    // Spatial radius (in CSS / world coords) within which a visitor is
    // "near" an artifact for purposes of pulling from that artifact's pool.
    // Storefronts are 100pt wide, artifacts 18-80pt; 40pt radius lets
    // visitors in the central corridor find their way to artifact thoughts.
    static let artifactProximityRadius: Double = 40

    // v9 Prompt 4 Phase 3 — memory weight increment per thought fire (before
    // cohort multiplier). Cohort multipliers are on AgeCohort.
    //
    // v9 patch — halved from 0.5 to 0.25 to offset the base-tick slowdown
    // (Speed.tickIntervalMs 1x: 4000 → 8000). Visitor thoughts fire on a
    // real-time cadence (20-30s per visitor), so doubling the real-time
    // duration of a game-month would have doubled thoughts-per-game-month
    // — and memory weight with it. Halving the per-thought increment holds
    // memory-per-game-month constant, preserving the baseVacancyRate = 2.0
    // ratio target (65:35 to 75:25 vacancy:memory at month 36). Total
    // memory over a full real-time run is unchanged.
    static let memoryWeightBaseIncrement: Double = 0.25
}

// v9 Prompt 4 Phase 4 — visual indicator threshold.
// Artifacts with memoryWeight ≥ this value gain a subtle pulse. Single
// constant so tuning is in one place.
enum MemoryWeight {
    static let visualThreshold: Double = 5.0
}
