import Foundation

// v9 Prompt 18 Phase B — the How to Play reference.
//
// HowToPlayContent.sections is the single array the reader view
// (Views/HowToPlayView.swift) renders. Each section is one title + one
// body paragraph (body CAN contain blank-line-separated subparagraphs —
// the view renders them as-is). Sections appear in the order defined
// here; the reader scrolls top-to-bottom.
//
// Section 10 ("Scoring in detail") is the canonical formula reference
// the player consults to optimize. If a value in Scoring.ScoringTuning
// changes, update Section 10 in parallel.

struct HowToPlaySection: Identifiable, Hashable {
    let id: Int
    let title: String
    let body: String
}

// v9 Prompt 20 — clear, structured reference copy. No marketing tone.
// Numeric values mirror current Scoring.ScoringTuning; update in parallel
// if those tune. Section 10 is the formula reference the player consults
// to optimize.
enum HowToPlayContent {

    static let sections: [HowToPlaySection] = [

        HowToPlaySection(
            id: 1,
            title: "What the game is",
            body: """
            You've inherited a mall in a small-town American midwest, January 1982. You did not build it, and you cannot save it.

            The goal is to let the mall become what it is going to become. A dead mall. A quiet one. A curated one. The one photographed forty years after opening day, with a pretzel kiosk still open in the center court and a skylight that leaks.

            There are two ways to lose. Bankruptcy, if debt runs past the ceiling. Forgotten, if the mall goes dark and nobody remembers it. Staying open and staying remembered are the same job.
            """
        ),

        HowToPlaySection(
            id: 2,
            title: "Time and pacing",
            body: """
            Time advances one month per tick. At 1× speed, a month is about eight seconds of real time.

            Speed controls are in the bottom right: 1× / 2× / 4× / 8×. Pause halts everything, including visitor animation. Decision cards and tutorial beats auto-pause the game; dismissing them resumes at the previous speed.

            Most actions do not require pausing. The game is paced so the player can react to a closure or an offer at 1× without feeling rushed.
            """
        ),

        HowToPlaySection(
            id: 3,
            title: "Cash and score",
            body: """
            Cash is a running balance. Rent is the only inflow. Operating costs, promotion costs, staff, and occasional events all subtract.

            Tap the cash cell in the HUD to open the P&L sheet, which itemizes the monthly change.

            Debt is capped at $25,000. Cross that ceiling and the run ends in bankruptcy.

            Score is monthly, cumulative, and never resets. Score comes from three sources: empty storefront score, memory score, and the action burst bonus. See Scoring in detail for the formula.
            """
        ),

        HowToPlaySection(
            id: 4,
            title: "Tenants and tiers",
            body: """
            Tenants are classified into tiers:

            • Anchor. Large wing-defining stores (Halvorsen, Pemberton). Their closure triggers a wing cascade.
            • Standard. The body of the mall. Retail. Two- to three-year leases.
            • Kiosk. Small, cheap, short leases. Flighty.
            • Sketchy. Pawn, vape, escape rooms. Low rent, low traffic, low threshold. Late-run takers.
            • Specialty. Podiatrists, tax preparers, hearing aid centers, financial advisors. Immune to traffic-based closure. Four- to five-year leases. Rare early, common late.
            • Vacant. Empty slot. No tenant, no rent, vacancy penalty.

            Offer mix shifts with the mall's state. A thriving mall sees standards and good kiosks; a dead mall sees specialty and sketchy.
            """
        ),

        HowToPlaySection(
            id: 5,
            title: "Closures and memorials",
            body: """
            When a tenant closes, the storefront is not cleared. It becomes a boardedStorefront artifact: a memorial at that slot.

            Memorials accrue memory weight the same way any artifact does: visitors pass nearby, and a thought fires that references the memorial.

            A memorial can be left boarded, sealed permanently, or curated into a display. Accepting a new tenant offer in that slot destroys the memorial and takes its memory weight with it. The ledger logs the destruction.
            """
        ),

        HowToPlaySection(
            id: 6,
            title: "The three memorial verbs",
            body: """
            Board. Automatic. When a tenant closes, their storefront becomes a boardedStorefront. Full memory accrual rate. No maintenance cost. A new tenant can sign on top of it.

            Seal. Player action. Drywalls the slot permanently. Memory accrues at half rate. No maintenance cost. Irreversible. New tenants cannot sign a sealed slot.

            Display. Player action. Converts the slot to a displaySpace with one of five content variants (vintage photos, community art, seasonal vignette, historical plaque, local artist showcase). Memory accrues at 1.5×. Costs $75 per month in maintenance. Revertible to boarded at any time.
            """
        ),

        HowToPlaySection(
            id: 7,
            title: "Memory weight",
            body: """
            Memory weight is the score substrate. Every artifact carries one. It rises and falls based on what visitors think about.

            Accrual. When a visitor walks near an artifact and a thought fires that references it, the artifact's memory weight increases. The cohort of the visitor scales the increment: Originals (elders) at 2.5×, Nostalgics (middle-aged) at 1.5×, Explorers (kids and teens) at 1.0×.

            Pool access. Older cohorts see a bigger slice of the artifact's thought pool. Explorers see only the universal front entries; Originals see the entire pool, including the deep cuts.

            Modifiers. Seal multiplies accrual by 0.5. Display multiplies by 1.5.

            Decay. After six months without a new thought, memory weight decays five percent per month. Run a dead artifact past anyone and accrual resumes.
            """
        ),

        HowToPlaySection(
            id: 8,
            title: "The mall state machine",
            body: """
            The mall moves through six environmental states:

            thriving → fading → struggling → dying → dead → ghostMall

            State is computed from traffic, occupancy, and overall decay. The transition is automatic; there is no manual override.

            Each state changes multiple systems at once. Scoring multipliers rise as the state worsens. Visitor mix shifts toward photographers, urbex explorers, and paranormal investigators. Operating costs scale. Visual tone (lighting, audio, color grade) darkens.

            ghostMall is a special state: five consecutive years in dead. Scoring multiplier is maxed. Visitor mix is entirely late-game cohorts. This is the endgame state the game is built around.
            """
        ),

        HowToPlaySection(
            id: 9,
            title: "Anchors and the cascade",
            body: """
            Anchors occupy wing slots and pay large rent. Their closure is the single largest structural event in a run.

            When an anchor closes:

            • The wing loses 25 percent of its traffic, permanently.
            • The wing darkens one environmental band below the mall.
            • The anchor's stopped escalator and lost signage spawn as ambient artifacts in the corridor.
            • Every non-anchor tenant in the wing receives a +1 hardship tick per month for three months (the cascade). Many close as a result.

            The cascade card is the most emotionally weighty moment in a run. The ledger records the anchor's name, the wing, and every coincident closure. Read it.
            """
        ),

        HowToPlaySection(
            id: 10,
            title: "Scoring in detail",
            body: """
            Monthly score = emptyScore + memoryContribution + actionBurst

            emptyScore = (emptyStorefronts × emptyWeight) + (sealedWings × sealedWingWeight)
                        × yearCurve × lifeMultiplier × (1 + aestheticMult)

            memoryScore = Σ over all artifacts of artifact.memoryWeight
            memoryContribution = memoryScore × stateMemoryMultiplier × yearCurve × lifeMultiplier

            actionBurst = max(0, stateMemoryMultiplier − 1.0) × actionBurstBase
                        Fires when a curation action (seal, display, place) happens in struggling or worse.

            yearCurve is a quadratic passing through: year 0 → 1.0, year 5 → 3.0, year 10 → approximately 6.0. Uncapped. Rewards long survival.

            lifeMultiplier = min(1.0, currentTraffic / 100). Zero if fewer than two tenants or if traffic is below 30. The mall must be alive enough to score.

            stateMemoryMultiplier by state:
              thriving 1.0 · fading 1.0 · struggling 1.2 · dying 1.5 · dead 1.8 · ghostMall 2.0

            actionBurstBase is 50. emptyWeight, sealedWingWeight, and aestheticMult are current values in Scoring.ScoringTuning and may change with tuning passes.

            Intuition. The formula rewards long survival and late-game curation far more than early rent-maxing. A mall in ghostMall at year 10 with a handful of sealed wings and well-curated memorials scores orders of magnitude more per month than a rent-optimized mall at year 2.
            """
        ),

        HowToPlaySection(
            id: 11,
            title: "Two failure modes",
            body: """
            Bankruptcy. Debt exceeds $25,000. The run ends immediately. This is the failure mode for runs that keep the mall too full: standard-tier rent cannot outpace anchor-loss operating costs once the cascade fires.

            Forgotten. Three conditions must hold at once:
              • Total memory weight across all artifacts is below 15.0
              • Traffic has been below 15 for twelve or more consecutive months
              • The mall has been in dead for twenty-four or more consecutive months

            The run ends. This is the failure mode for runs that let the mall go dark without curating the memorial layer. Specialty tenants, sealed wings, and display spaces all push memory weight up and pull the mall away from this edge.
            """
        ),

        HowToPlaySection(
            id: 12,
            title: "Endgame guidance",
            body: """
            The target is ghostMall: five consecutive years in dead.

            The rough playbook:

            • Keep one or two specialty tenants signed for rent. They do not close from low traffic.
            • Let standard tenants close when their leases lapse. Do not fight it.
            • Seal wings that cascade closed. The operating cost savings keep the run solvent.
            • Curate selected memorials as display spaces. Historical plaques and vintage mall photos on specific anchor slots make the difference in late-game memory score.
            • Keep memory weight well above the forgotten threshold before the mall ever enters dead.

            See ENDGAME.md for the design intent: the forty-minutes-in mall the game exists to produce.
            """
        ),

        HowToPlaySection(
            id: 13,
            title: "Credits and acknowledgments",
            body: """
            Design, programming, and writing: Trevor Riggle / RIG Tech LLC.

            Pixel art: Christian.

            Based on the v8 browser prototype. The iPad port diverges intentionally from v8 in several places; see the codebase's v9 annotations for specifics.

            Music, sound, and any third-party library credits will be filled in ahead of ship. This section is scaffolding.
            """
        ),
    ]
}
