import Foundation

// v9 Prompt 21 Fix 2 — artifact decay + hazard tuning constants, extracted
// from inline TickEngine / Economy literals. Audit summary that drove these
// values (recorded in TUNING.md):
//
//   Before:  decay per tick   = (0.02 + condition * 0.01) * janitorialMult
//            hazard on decay-to-4 roll  = 0.40
//            hazard on already-at-4 roll = 0.15
//            hazard fines             = every hazarded artifact every tick
//   After:   decay per tick   = (0.01 + condition * 0.005) * janitorialMult
//            hazard on decay-to-4 roll  = 0.20
//            hazard on already-at-4 roll = 0.075
//            hazard fines             = at most one fine per tick (largest)
//
// Rationale: pre-Prompt-21 playtesting showed pipes + HVAC failing too
// frequently and stacking hazard fines dominated cash flow late-run. The
// condition threshold for hazard emission (>= 4) is already above what the
// Prompt 21 bullet called out ("if hazard fine threshold is condition 2+");
// no change needed on that axis.
enum ArtifactTuning {

    // Per-tick decay roll baseline. A pristine (condition 0) artifact has
    // this probability to advance one condition step per tick; higher
    // conditions add decayConditionStep × current condition. Janitorial
    // staff halves the final probability.
    static let decayBaseProbability: Double = 0.01

    // Per-condition decay probability addend. At condition c, the chance
    // is decayBaseProbability + c * decayConditionStep.
    static let decayConditionStep: Double = 0.005

    // Probability that an artifact is flagged as a hazard on the tick that
    // its condition advances to ruin (4). Fires immediately after the
    // decay transition — one roll per artifact per promotion.
    static let hazardOnDecayToRuinChance: Double = 0.20

    // Probability that an artifact at condition 4 (ruin) without the
    // hazard flag acquires it on a subsequent tick. Fires each tick until
    // the flag sticks or the artifact is repaired/removed.
    static let hazardAtRuinChance: Double = 0.075

    // v9 Prompt 21 Fix 2 — cap on how many hazard fines fire per tick. One
    // means only the single largest outstanding fine is billed per month;
    // the other hazarded artifacts still exist on scene and still motivate
    // repair, they just don't stack into one cash-bleed event.
    static let maxHazardFinesPerTick: Int = 1
}
