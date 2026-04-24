import Foundation

// v9 Prompt 18 — observational detector for tutorial beats that trigger
// on state changes rather than UI actions. Called by GameViewModel.tickOnce
// after TickEngine.tick returns; returns the set of beats whose triggers
// fired this tick. Caller handles queueing via fireBeat (which does the
// one-shot-per-run guard against tutorialBeatsSeen).
//
// Design rules:
//   - Pure: reads state only, returns a list. No state mutation here.
//   - Idempotent per beat: duplicate detection is the caller's problem.
//     If a beat's trigger is "persistently true" (e.g. any sealed
//     artifact exists), scan will re-report it every tick; fireBeat's
//     seen-set silently drops repeats. This keeps the detector itself
//     simple — no history stashing, no "previously-observed" snapshots.
//   - Non-fabricating: every trigger inspects state the player actually
//     produced. The detector never synthesizes a moment to fire a beat.
//     If the player never seals a wing, .firstSealedWingSaving never
//     fires. If the player never curates, .firstActionBurst never fires.
//   - Tutorial-disabled bypass: scan returns immediately when
//     tutorialEnabled is false. This is the SC4 parity seam — a
//     disabled-tutorial run must produce identical state to a pre-
//     Prompt-18 run, and the cheapest way to guarantee that is to never
//     compute any detector result when the player opted out.
//
// UI-triggered beats (manageDrawer, firstLedgerView, firstVisitorThought)
// are not detected here — views call GameViewModel.fireBeat directly.
// They share the same idempotency guard; the split is just about where
// the trigger originates.
enum TutorialBeatDetector {

    // How many months before the forgotten-failure trip to fire
    // .approachingForgotten. Player sees the beat while both counters
    // are still climbing but within striking distance. Tuned against
    // FailureTuning.trafficFloorMonths (12) and .deadOrGhostMonths
    // (24): firing at 3 months remaining means we have enough buffer
    // for the player to read and react without the run immediately
    // ending on the next tick.
    static let approachingForgottenLeadMonths: Int = 3

    static func scan(_ state: GameState) -> [TutorialBeat] {
        guard state.tutorialEnabled else { return [] }

        var triggered: [TutorialBeat] = []

        // ---------- Placement / memorial verbs ----------
        // Any artifact with a catalog cost > 0 means the player placed
        // something from the Acquire list (memorial artifacts like
        // boardedStorefront / sealedEntrance / emptyFoodCourt are
        // cost-zero and excluded here).
        if state.artifacts.contains(where: {
            ArtifactCatalog.info($0.type).cost > 0
        }) {
            triggered.append(.firstPlacement)
        }

        // First time the player has sealed a boarded storefront. Any
        // artifact of type .sealedStorefront is enough — the verb fires
        // once per storefront slot, so one presence in the array means
        // the player clicked Seal at least once.
        if state.artifacts.contains(where: { $0.type == .sealedStorefront }) {
            triggered.append(.firstSeal)
        }

        // First displaySpace curation.
        if state.artifacts.contains(where: { $0.type == .displaySpace }) {
            triggered.append(.firstDisplay)
        }

        // v9 Prompt 19 — first time there's a boarded memorial on the
        // scene the player could act on. Fires in the tick AFTER a
        // tenant closure spawns the artifact (TenantLifecycle appends to
        // state.artifacts inside the same tick; the detector runs after
        // the tick returns). Distinct from firstClosure — that beat
        // fires on the ledger entry; this one fires on the actionable
        // artifact being available.
        if state.artifacts.contains(where: { $0.type == .boardedStorefront }) {
            triggered.append(.firstBoardedStorefront)
        }

        // v9 Prompt 19 — first wing that's dropped below 50% non-vacant
        // occupancy. Mirrors the Sealing.wingOccupancyAdvisory threshold —
        // below 50% is the inflection where sealing becomes an obvious
        // move rather than an aggressive one. Uses non-closed wings so
        // an already-sealed wing doesn't re-trigger.
        for wing in Wing.allCases where !Mall.isWingClosed(wing, in: state) {
            let stores = state.stores.filter { $0.wing == wing }
            guard !stores.isEmpty else { continue }
            let active = stores.filter { $0.tier != .vacant }.count
            let ratio = Double(active) / Double(stores.count)
            if ratio < 0.5 {
                triggered.append(.firstWingEligibleForSealing)
                break   // one fire per run; detector dedupes anyway
            }
        }

        // ---------- Tenant offers / closures ----------
        if case .tenant(let offer)? = state.decision {
            triggered.append(.firstTenantOffer)
            // v9 Prompt 17 — specialty tier teaches a different lesson
            // (immuneToTrafficClosure, long lease); fire in addition to
            // the generic tenant-offer beat the first time the player
            // sees a specialty offer specifically.
            if offer.tier == .specialty {
                triggered.append(.firstSpecialtyOffer)
            }
        }

        // First closure anywhere in the ledger — any .closure entry.
        // Anchor departures don't route through .closure (they emit
        // .anchorDeparture, handled below), so this won't double-fire
        // when anchor 0 is the first to go.
        if state.ledger.contains(where: {
            if case .closure = $0 { return true } else { return false }
        }) {
            triggered.append(.firstClosure)
        }

        // ---------- Hazards / decay ----------
        // Any hazard-flagged artifact on the scene. Hazards surface via
        // TickEngine's decay path or via scripted event spawns; either
        // qualifies as "the player has encountered a hazard."
        if state.artifacts.contains(where: { $0.hazard }) {
            triggered.append(.firstHazard)
        }

        // ---------- Environmental ladder ----------
        // Any .envTransition entry in the ledger. The first such entry
        // fires the beat; subsequent ones silently no-op via the seen
        // set. Covers both decline (thriving→fading) and recovery
        // (fading→thriving) — the lesson is "the mall has bands," not
        // a specific direction.
        if state.ledger.contains(where: {
            if case .envTransition = $0 { return true } else { return false }
        }) {
            triggered.append(.firstEnvTransition)
        }

        let env = EnvironmentState.from(state)
        if env == .dying {
            triggered.append(.firstMallDying)
        }
        if env == .dead {
            triggered.append(.firstMallDead)
        }
        if env == .ghostMall {
            triggered.append(.firstGhostMall)
        }

        // ---------- Anchor cascade ----------
        // Fires on the first anchor departure. We key off the ledger
        // rather than the card queue because the queue drains as cards
        // are dismissed — but .anchorDeparture entries are permanent in
        // the ledger. Either signal works, the ledger is more durable.
        if state.ledger.contains(where: {
            if case .anchorDeparture = $0 { return true } else { return false }
        }) {
            triggered.append(.firstAnchorDeparture)
        }

        // ---------- Economic legibility: sealed wing saves cash ----------
        // Fires the first tick where the mall has at least one closed
        // wing. The beat teaches that sealing is an economic tool —
        // Economy.operatingCost subtracts sealedWingSavings per closed
        // wing, so any wing closure produces a visible ops reduction.
        // Detector checks the flag directly rather than re-running
        // Economy.operatingCost on a hypothetical baseline; the wing
        // is either closed (saving shows up in ops) or not, and the
        // card copy explains the mechanic.
        if Mall.isWingClosed(.north, in: state)
            || Mall.isWingClosed(.south, in: state) {
            triggered.append(.firstSealedWingSaving)
        }

        // ---------- Action burst ----------
        // First tick where Scoring.actionBurst returns > 0. The burst
        // is env-gated (struggling+) so this also acts as a "you've
        // reached a state where curation starts paying off" signal.
        if Scoring.actionBurst(for: state) > 0 {
            triggered.append(.firstActionBurst)
        }

        // ---------- Failure mode: approaching forgotten ----------
        // All three memorial-failure conditions are "partially" true —
        // both timer counters are within approachingForgottenLeadMonths
        // of their trips, and totalMemoryWeight is already under the
        // threshold. Fires with enough lead time to let the player
        // react (place a display, curate an artifact, approach a
        // tenant to boost traffic).
        if state.totalMemoryWeight < FailureTuning.memoryFailureThreshold {
            let trafficLead = FailureTuning.trafficFloorMonths
                            - approachingForgottenLeadMonths
            let deadLead = FailureTuning.deadOrGhostMonths
                         - approachingForgottenLeadMonths
            let trafficNear = state.consecutiveMonthsBelowTrafficFloor >= trafficLead
            let deadNear = state.monthsInDeadState >= deadLead
            // Gate on "still pre-trip": if the run is already over
            // (gameover true) we don't fire — the end screen is up.
            if trafficNear && deadNear && !state.gameover {
                triggered.append(.approachingForgotten)
            }
        }

        return triggered
    }
}
