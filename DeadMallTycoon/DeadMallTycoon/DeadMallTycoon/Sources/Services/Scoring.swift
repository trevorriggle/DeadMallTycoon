import Foundation

// v8: monthlyScore(), getLifeMultiplier(), and the year-multiplier curve.
// The year-multiplier function is isolated so Phase 5 can swap in the v9 progressive curve
// without touching monthlyScore.
//
// v9 Prompt 5 — monthlyScore is rewritten to honor two substrates simultaneously:
//   1. vacancyScore — raw emptiness × baseVacancyRate (the thesis's "empty is good")
//   2. memoryScore  — Σ artifact.memoryWeight × artifact.decayMultiplier
//                     (what visitors actually remember about the space)
//
// Monthly Score = (vacancyScore + memoryScore) × yearMult × lifeMult
//
// aestheticMult was previously a × multiplier on the old score; it is no longer
// consumed by scoring as of Prompt 5. See Economy.aestheticMult for its
// documented kill-date.
enum Scoring {

    // v9 Prompt 5 — tuning knobs for the split-substrate formula.
    // Target ratio at month 36: vacancyScore:memoryScore ≈ 65:35 to 75:25
    // (vacancy dominant, memory meaningful supplement). If live play shows
    // memory dominating, baseVacancyRate is the first dial to raise.
    enum ScoringTuning {
        static let baseVacancyRate: Double = 2.0
    }

    // v9 Prompt 5 — totalEmptiness extracted as helper so vacancyScore and
    // downstream UI (PnL Score Sources) can share it without duplicating the
    // sealed-wing formula. Matches the v8 shape: vacantOpen + 5 per sealed wing.
    static func totalEmptiness(_ state: GameState) -> Int {
        let vacantOpen = Mall.openStores(state).filter { $0.tier == .vacant }.count
        let sealedBonus =
            (Mall.isWingClosed(.north, in: state) ? 5 : 0) +
            (Mall.isWingClosed(.south, in: state) ? 5 : 0)
        return vacantOpen + sealedBonus
    }

    // v9 Prompt 5 — raw vacancy substrate, pre-multipliers.
    static func vacancyScore(_ state: GameState) -> Double {
        Double(totalEmptiness(state)) * ScoringTuning.baseVacancyRate
    }

    // v9 Prompt 5 — memory substrate. Each artifact contributes
    // memoryWeight × decayMultiplier. Fresh mall = 0 (no thoughts fired yet).
    static func memoryScore(_ state: GameState) -> Double {
        state.artifacts.reduce(0.0) { $0 + $1.memoryWeight * $1.decayMultiplier }
    }

    // v8: monthlyScore()
    // v9 Prompt 5 — rewrite. Formula is now (vacancyScore + memoryScore) ×
    // yearMult × lifeMult. The v8 × aestheticMult term has been dropped from
    // scoring (aestheticMult retained for now — see Economy.aestheticMult for
    // kill-date notes). The v8 `totalEmptiness == 0 → 0` gate has also been
    // removed: memory is an independent substrate and should score even when
    // vacancy is briefly zero. The tenants≥2 and traffic≥30 gates remain.
    static func monthlyScore(_ state: GameState) -> Int {
        let openStores = Mall.openStores(state)
        let activeTenants = openStores.filter { $0.tier != .vacant }.count
        if activeTenants < 2   { return 0 }
        if state.currentTraffic < 30 { return 0 }

        let lifeMultiplier = min(1.0, Double(state.currentTraffic) / 100.0)
        let yr = Double(state.year - GameConstants.startingYear) + Double(state.month) / 12.0
        let yearMult = yearMultiplier(yearsElapsed: yr)

        let substrate = vacancyScore(state) + memoryScore(state)
        let raw = substrate * yearMult * lifeMultiplier
        return Int(raw)
    }

    // v8: getLifeMultiplier()
    static func lifeMultiplier(_ state: GameState) -> Double {
        let activeTenants = Mall.openStores(state).filter { $0.tier != .vacant }.count
        if activeTenants < 2 { return 0 }
        if state.currentTraffic < 30 { return 0 }
        return min(1.0, Double(state.currentTraffic) / 100.0)
    }

    // v9: progressive, uncapped year curve.
    // Quadratic fit through target anchors:
    //   y=0  → ~1.0×    y=1  → ~1.18×
    //   y=5  → ~3.0×
    //   y=10 → ~7.7×   (≈ 8× target)
    //   y=15 → ~15.2×
    //   y=20 → ~25.4×   (uncapped; continues rising)
    // Rewards long-term survival dramatically more than v8's cap of 4× at year 25.
    // Old v8 curve for reference: `1.0 + min(yr * 0.12, 3.0)`
    static func yearMultiplier(yearsElapsed yr: Double) -> Double {
        0.055 * yr * yr + 0.12 * yr + 1.0
    }
}
