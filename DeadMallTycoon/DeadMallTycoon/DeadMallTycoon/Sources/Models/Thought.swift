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
    static let memoryWeightBaseIncrement: Double = 0.5
}

// v9 Prompt 4 Phase 4 — visual indicator threshold.
// Artifacts with memoryWeight ≥ this value gain a subtle pulse. Single
// constant so tuning is in one place.
enum MemoryWeight {
    static let visualThreshold: Double = 5.0
}
