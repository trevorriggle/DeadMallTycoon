import Foundation

// v9 Prompt 18 Phase B — the How to Play reference.
//
// HowToPlayContent.sections is the single array the reader view
// (Views/HowToPlayView.swift) renders. Each section is one title + one
// body paragraph (body CAN contain blank-line-separated subparagraphs —
// the view renders them as-is). Sections appear in the order defined
// here; the reader scrolls top-to-bottom.
//
// Claude Code does NOT write these. The How to Play voice is Trevor's
// — longer-form than the tutorial beats, explains the WHY behind each
// mechanic, assumes the player has already played at least one run.
// See the AUTHORING TODO below. Pattern mirrors the tutorial copy
// file (Data/TutorialBeatCopy.swift) — placeholders are deliberately
// uninteresting so missing auth is visible.
//
// -----------------------------------------------------------------------------
// AUTHORING TODO — replace the body strings below. Voice: reference
// material a returning player consults for optimization. No marketing
// language. No introductions. Each section is self-contained; the
// player may open a section directly and read it in isolation.
//
//   [ ] 1.  "What the game is"
//   [ ] 2.  "Time and pacing"
//   [ ] 3.  "Cash and score"
//   [ ] 4.  "Tenants and tiers"
//   [ ] 5.  "Closures and memorials"
//   [ ] 6.  "The three memorial verbs"
//   [ ] 7.  "Memory weight"
//   [ ] 8.  "The mall state machine"
//   [ ] 9.  "Anchors and the cascade"
//   [ ] 10. "Scoring in detail"          ← MUST BE COMPLETE FORMULA REFERENCE
//   [ ] 11. "Two failure modes"
//   [ ] 12. "Endgame guidance"
//   [ ] 13. "Credits and acknowledgments"
//
// Section 10 is the reference the player consults to optimize. The
// placeholder below describes the structure the authored version needs:
// every multiplier named, every formula reproduced, every numeric
// constant given its current value. If a tuning value changes, the
// section is updated. See Scoring.swift for the canonical source.
// -----------------------------------------------------------------------------

struct HowToPlaySection: Identifiable, Hashable {
    let id: Int
    let title: String
    let body: String
}

enum HowToPlayContent {

    static let sections: [HowToPlaySection] = [

        HowToPlaySection(
            id: 1,
            title: "What the game is",
            body: "[howtoplay pending: the mall is inherited, not built. The goal is to keep it barely open — empty enough to score, full enough to pay costs. Bankruptcy and being forgotten are both losses.]"
        ),

        HowToPlaySection(
            id: 2,
            title: "Time and pacing",
            body: "[howtoplay pending: time advances one month per tick. 1x is 8 seconds per month. Speed buttons (1×/2×/4×/8×) live bottom-right. Paused halts everything including animation. Decisions and tutorial cards auto-pause; closing them resumes.]"
        ),

        HowToPlaySection(
            id: 3,
            title: "Cash and score",
            body: "[howtoplay pending: cash pays operating costs; rent is the only inflow. Score is monthly, cumulative, never resets. Tap the cash cell to open the P&L. Debt ceiling is $25,000 — bankruptcy at that value.]"
        ),

        HowToPlaySection(
            id: 4,
            title: "Tenants and tiers",
            body: "[howtoplay pending: six tiers (anchor / standard / kiosk / sketchy / specialty / vacant). Anchors occupy wing slots and their closure triggers the cascade. Specialty tenants are immune to traffic-based closure and lease 3-5 years. Kiosks are small, cheap, and flighty.]"
        ),

        HowToPlaySection(
            id: 5,
            title: "Closures and memorials",
            body: "[howtoplay pending: when a tenant closes, the storefront becomes a boardedStorefront artifact (memorial). It accrues memory weight as visitors think about it. Boarded can be sealed (preserved forever) or curated into a displaySpace. Accepting a new offer in that slot destroys the memorial.]"
        ),

        HowToPlaySection(
            id: 6,
            title: "The three memorial verbs",
            body: "[howtoplay pending: Board (automatic on closure), Seal (irreversible preservation; half memory accrual; no maintenance), Display (active curation; 1.5× memory accrual; monthly maintenance cost; revertible to boarded).]"
        ),

        HowToPlaySection(
            id: 7,
            title: "Memory weight",
            body: "[howtoplay pending: memory weight accrues when visitors tap thoughts that reference an artifact. Cohort matters (Originals 2.5×, Nostalgics 1.5×, Explorers 1.0×). Seal halves accrual rate; Display multiplies by 1.5×. Memory decays 5%/month after 6 months of no thoughts.]"
        ),

        HowToPlaySection(
            id: 8,
            title: "The mall state machine",
            body: "[howtoplay pending: six environmental states (thriving / fading / struggling / dying / dead / ghostMall). State is computed from traffic, occupancy, and decay. Each state changes scoring multipliers, operating costs, visitor counts, and visual tone.]"
        ),

        HowToPlaySection(
            id: 9,
            title: "Anchors and the cascade",
            body: "[howtoplay pending: when an anchor closes, the wing loses 25% traffic permanently and darkens one band below the mall. Non-anchor tenants in that wing receive +1 hardship per month for 3 months (the cascade). This is usually the single largest structural change a run sees.]"
        ),

        HowToPlaySection(
            id: 10,
            title: "Scoring in detail",
            body: """
            [howtoplay pending: complete formula reference. MUST enumerate:

            Monthly score = emptyScore + memoryContribution + actionBurst

            emptyScore   = (emptyStorefronts × emptyWeight) + (sealedWings × sealedWingWeight)
                         × yearCurve × lifeMultiplier × (1 + aestheticMult)

            memoryScore  = Σ artifact.memoryWeight (raw substrate)
            memoryContrib = memoryScore × stateMemoryMultiplier × yearCurve × lifeMultiplier

            actionBurst  = max(0, stateMemoryMultiplier − 1.0) × actionBurstBase
                           (fires when a curation action happens in a struggling+ state)

            yearCurve    = quadratic through (y=0 → 1.0), (y=5 → 3.0), (y=10 → ~6.0), uncapped
            lifeMultiplier = min(1.0, currentTraffic/100); 0 if <2 tenants or traffic <30

            stateMemoryMultiplier by EnvironmentState:
              thriving 1.0 · fading 1.0 · struggling 1.2 · dying 1.5 · dead 1.8 · ghostMall 2.0

            actionBurstBase = 50
            emptyWeight (per storefront), sealedWingWeight (per closed wing), aestheticMult —
              see Scoring.ScoringTuning for current values.

            Authored version: walk through worked examples at year 1, year 5, year 10, at
            thriving vs dying vs ghostMall, with and without curation. Show how each
            multiplier combines. Include the intuition for why the formula rewards
            long survival + late-game curation rather than early rent-maxing.]
            """
        ),

        HowToPlaySection(
            id: 11,
            title: "Two failure modes",
            body: "[howtoplay pending: Bankruptcy — debt exceeds $25,000. Forgotten — three simultaneous conditions: total memoryWeight < 15.0, traffic below 15 for 12+ consecutive months, mall state == dead for 24+ consecutive months. Occupied runs tend toward bankruptcy; neglectful runs tend toward forgotten.]"
        ),

        HowToPlaySection(
            id: 12,
            title: "Endgame guidance",
            body: "[howtoplay pending: the target is ghostMall — five consecutive years in .dead. The play is: keep one or two specialty tenants for rent, let everything else close, curate the memorials, seal the wings that cascade closed. Memory weight should be well above the forgotten threshold before the mall ever enters dead. See ENDGAME.md for design intent.]"
        ),

        HowToPlaySection(
            id: 13,
            title: "Credits and acknowledgments",
            body: "[howtoplay pending: credits — RIG Tech LLC (Trevor Riggle, solo developer), Christian (pixel art), music licensing credits, any third-party libraries or assets with license terms. Authored in full by Trevor before ship.]"
        ),
    ]
}
