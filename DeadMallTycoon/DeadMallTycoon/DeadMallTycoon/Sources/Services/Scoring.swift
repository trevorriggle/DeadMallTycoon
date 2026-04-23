import Foundation

// v8: monthlyScore(), getLifeMultiplier(), and the year-multiplier curve.
// The year-multiplier function is isolated so Phase 5 can swap in the v9 progressive curve
// without touching monthlyScore.
//
// v9 Prompt 5 — monthlyScore split into two substrates:
//   1. vacancyScore — raw emptiness × baseVacancyRate (the thesis's "empty is good")
//   2. memoryScore  — Σ artifact.memoryWeight × artifact.decayMultiplier
//                     (what visitors actually remember about the space)
//
// v9 Prompt 13 — state-dependent scoring. Four interlocking mechanisms:
//
//   (a) stateMemoryMultiplier multiplies the memory substrate by a
//       per-EnvironmentState value. Memory becomes more rewarded as the
//       mall declines — 1.0 at thriving, 2.0 at ghostMall.
//
//   (b) Gate split. vacancyContribution keeps the v5 strict gate
//       (activeTenants >= 2 AND currentTraffic >= 30) — "can't coast on
//       emptiness" emerges naturally as tenants drop below 2.
//       memoryContribution relaxes to activeTenants >= 1 so the
//       ENDGAME fantasy works ("one tenant remains, mall still scoring
//       from accumulated memory").
//
//   (c) actionBurst. Curation actions (seal, place, repurpose-as-
//       display) grant immediate score events that scale with state:
//       0 at thriving/fading, 10/25/40/50 at struggling/dying/dead/
//       ghost. At ghostMall these become the dominant score source —
//       per spec, "passive play scores near-zero."
//
//   (d) Memory weight decay (driven from TickEngine): artifacts not
//       thought of within memoryDecayMonths lose memoryDecayRatePerMonth
//       per tick. Counterweights accumulation; keeps passive-play score
//       from being a one-way ratchet.
//
// aestheticMult was previously a × multiplier on the old score; it is no longer
// consumed by scoring as of Prompt 5. See Economy.aestheticMult for its
// documented kill-date.
enum Scoring {

    // v9 Prompt 5 — tuning knobs for the split-substrate formula.
    // v9 Prompt 13 — extended with state-dependent dials.
    // Target ratio at month 36: vacancyScore:memoryScore ≈ 65:35 to 75:25
    // (vacancy dominant, memory meaningful supplement). If live play shows
    // memory dominating, baseVacancyRate is the first dial to raise.
    enum ScoringTuning {
        static let baseVacancyRate: Double = 2.0

        // v9 Prompt 13 — per-state memory multiplier. Memory becomes
        // more rewarded as the mall ages. At ghostMall, memory is
        // worth 2× baseline — but it only scores if the player keeps
        // artifacts "lived in" (memory decay below) and the 1+ tenant
        // holdout is present (gate in monthlyScore).
        static let stateMemoryMultiplier: [EnvironmentState: Double] = [
            .thriving:   1.0,
            .fading:     1.0,
            .struggling: 1.2,
            .dying:      1.5,
            .dead:       1.8,
            .ghostMall:  2.0,
        ]

        // v9 Prompt 13 — base action-burst value. Multiplied by
        // max(0, stateMemoryMultiplier − 1.0) so bursts start at
        // struggling (10), grow at dying (25) / dead (40), peak at
        // ghostMall (50). Thriving and fading yield 0 — bursts aren't
        // a scoring mechanic at those states per spec.
        static let actionBurstBase: Double = 50

        // v9 Prompt 13 — memory weight decay: after this many months
        // without a thought firing on an artifact, memoryWeight begins
        // to decay at memoryDecayRatePerMonth per tick.
        static let memoryDecayMonths: Int = 6

        // v9 Prompt 13 — per-month fractional loss once decay kicks in.
        // 0.05 = 5% of current memoryWeight per tick. Multiplicative, so
        // weight approaches but never reaches zero. Halves roughly every
        // 14 months of uninterrupted neglect.
        static let memoryDecayRatePerMonth: Double = 0.05
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
    // This is the RAW substrate — stateMemoryMultiplier is applied in
    // monthlyScore, not here, so callers inspecting memoryScore directly
    // (PnL UI, tests) see the state-free value.
    static func memoryScore(_ state: GameState) -> Double {
        state.artifacts.reduce(0.0) { $0 + $1.memoryWeight * $1.decayMultiplier }
    }

    // v8: monthlyScore()
    // v9 Prompt 5 — split-substrate rewrite.
    // v9 Prompt 13 — gate split + state multiplier.
    //
    // Formula:
    //   vacancyContribution = vacancyScore × yearMult × lifeMult
    //     gated by: activeTenants >= 2 AND currentTraffic >= 30
    //   memoryContribution  = memoryScore × stateMemoryMultiplier × yearMult × lifeMult
    //     gated by: activeTenants >= 1
    //   monthlyScore = vacancyContribution + memoryContribution
    //
    // lifeMult (traffic/100 capped at 1.0) applies to BOTH substrates so
    // ambient traffic density modulates overall reward. Memory bypasses
    // only the HARD traffic gate (<30 instant-zero), not the lifeMult
    // curve — at very low traffic the memory contribution is damped, but
    // not zeroed. Combined with the decay mechanism, this produces the
    // ENDGAME curve: passive play at ghostMall is small-and-shrinking
    // unless the player keeps the mall lived-in through curation.
    static func monthlyScore(_ state: GameState) -> Int {
        let openStores = Mall.openStores(state)
        let activeTenants = openStores.filter { $0.tier != .vacant }.count
        if activeTenants < 1 { return 0 }   // fully empty mall → no scoring at all

        let yr = Double(state.year - GameConstants.startingYear)
              + Double(state.month) / 12.0
        let yearMult = yearMultiplier(yearsElapsed: yr)
        let lifeMult = min(1.0, Double(state.currentTraffic) / 100.0)

        // Vacancy contribution — strict gates preserved.
        var vacancyContribution: Double = 0
        if activeTenants >= 2, state.currentTraffic >= 30 {
            vacancyContribution = vacancyScore(state) * yearMult * lifeMult
        }

        // Memory contribution — gate relaxed to activeTenants >= 1 (the
        // ENDGAME "one-tenant holdout" scene). Traffic-< 30 doesn't hard-
        // zero memory; lifeMult dampens at low traffic instead.
        let env = EnvironmentState.from(state)
        let stateMult = ScoringTuning.stateMemoryMultiplier[env] ?? 1.0
        let memoryContribution =
            memoryScore(state) * stateMult * yearMult * lifeMult

        return Int(vacancyContribution + memoryContribution)
    }

    // v9 Prompt 13 — immediate score event for a curation action (seal,
    // place, repurpose-as-display). Called from ArtifactActions at the
    // point of mutation; adds directly to state.score.
    //
    // Scales off stateMemoryMultiplier − 1.0 so bursts only fire at
    // struggling and beyond (where the multiplier is > 1.0). Thriving
    // and fading are deliberately burst-free — curation is a late-game
    // mechanic; no reward for rearranging deck chairs on a healthy mall.
    //
    //   thriving/fading  0
    //   struggling (1.2)  max(0, 0.2) × 50 = 10
    //   dying (1.5)       max(0, 0.5) × 50 = 25
    //   dead (1.8)        max(0, 0.8) × 50 = 40
    //   ghostMall (2.0)   max(0, 1.0) × 50 = 50
    static func actionBurst(for state: GameState) -> Int {
        let env = EnvironmentState.from(state)
        let mult = ScoringTuning.stateMemoryMultiplier[env] ?? 1.0
        let scaled = max(0.0, mult - 1.0) * ScoringTuning.actionBurstBase
        return Int(scaled.rounded())
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
