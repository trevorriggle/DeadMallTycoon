import Foundation

// v9 Prompt 14 — why the run ended. Two failure modes coexist:
// economic (bankruptcy, debt ceiling) and memorial (forgotten, sustained
// low-traffic + dead state + thin memory). Aggressive vacancy-maximizing
// runs tend toward bankruptcy; neglectful runs with full occupancy but no
// curation tend toward forgotten. The player's values determine which
// failure approaches.
enum GameOverReason: String, Codable {
    case bankruptcy
    case forgotten
}

// Root game state. Pure value type.
// Ported from the v8 `G` object. TickEngine.tick(state, rng) reads and returns a GameState.
struct GameState: Equatable {

    // clock — v8: G.m, G.y
    var month: Int = 0                    // 0..11
    var year: Int = GameConstants.startingYear

    // money — v8: G.cash, G.debt, G.score, G.lastMonthlyScore, G.hazardFines
    var cash: Int = GameConstants.startingCash
    var debt: Int = 0
    var score: Int = 0
    var lastMonthlyScore: Int = 0
    var hazardFines: Int = 0

    // world — v8: G.stores, G.decorations
    // Visitors are *presentation* state only — owned by MallScene, not GameState.
    // This keeps 60fps position updates out of the Observation loop. Identity (age,
    // personality, memory) is surfaced on selection via GameViewModel.recordVisitorInteraction.
    // v9 Prompt 3: the separate `decorations: [Decoration]` field was deleted;
    // every placed physical feature now lives in `artifacts` (the unified model).
    var stores: [Store] = []

    // v8: G.decorations (merged) + v9 Prompts 1-2 memorial entity (boardedStorefront, etc.).
    // v9 Prompt 3 — unified. Mechanic reads (aestheticMult, hazardFines,
    // threat, decay, warnings, events) all iterate this array.
    var artifacts: [Artifact] = []

    // operations — v8: G.spd, G.activePromos, G.activeAdDeals, G.activeStaff
    var speed: Speed = .x1
    var activePromos: [ActivePromotion] = []
    var activeAdDeals: [AdDeal] = []
    var activeStaff: StaffLoadout = StaffLoadout()
    var wingsClosed: [Wing: Bool] = [.north: false, .south: false]
    var wingsDowngraded: [Wing: Bool] = [.north: false, .south: false]

    // Entrance sealing — v9 iPad-port addition, no v8 equivalent. Set by TickEngine
    // monthly when mall state is struggling or worse. Distinct from wingsClosed:
    // sealing is an emergent late-game decay event (plywood over glass doors),
    // not a player action. Not reversible. All sealed → "functionally closed":
    // no new visitors spawn, existing drain out, corridor empties.
    //
    // v9 Prompt 6.5 — replaced the two-wing booleans (northEntranceSealed /
    // southEntranceSealed) with a per-corner set covering NW/NE/SW/SE. Clean
    // break — there is no saved-game format to migrate.
    var sealedEntrances: Set<EntranceCorner> = []

    // threat + traffic — v8: G.threatMeter, G.currentTraffic, G.consecutiveLowTrafficMonths, G.gangMonths
    var threatMeter: Double = 0
    var currentTraffic: Int = 0
    var consecutiveLowTrafficMonths: Int = 0
    var gangMonths: Int = 0

    // UI / flow — v8: G.currentTab, G.warnings, G.thoughtsLog, G.decision, G.paused, G.gameover, G.started, G.openingCrisis, G.pendingLawsuitMonth
    var currentTab: Tab = .mall
    var warnings: [Warning] = []
    var thoughtsLog: [ThoughtLogEntry] = []
    var decision: Decision? = nil
    var paused: Bool = false
    var gameover: Bool = false
    var started: Bool = false
    var openingCrisis: Bool = true
    var pendingLawsuitMonth: Int? = nil

    // selection — v8: G.selectedVisitor, G.selectedStore, G.selectedDec, G.selectedVisitorThought
    var selectedVisitorId: UUID? = nil
    var selectedStoreId: Int? = nil
    var selectedDecorationId: Int? = nil
    var selectedVisitorThought: String = ""
    // v9 Prompt 4 Phase 6 — frozen identity snapshot powering the profile panel.
    // Set by vm.selectVisitor, cleared by vm.clearSelection. See VisitorIdentity.
    var selectedVisitorIdentity: VisitorIdentity? = nil

    // v8: G.placingDecoration — placement mode for the old decoration picker.
    // v9 Prompt 3 — renamed to placingArtifactType; carries the unified
    // ArtifactType that the player chose in the Acquire tab.
    var placingArtifactType: ArtifactType? = nil

    // v9 addition — populated by TickEngine each month, rendered as sparkline in Phase 5
    var scoreHistory: RingBuffer<Int> = RingBuffer(capacity: 12)

    // tutorial — new in iOS port, no v8 equivalent.
    // activeTutorialStep drives the CoachmarkOverlay (Phase 2). tutorialSeenSteps
    // prevents a beat from firing twice. tutorialOwnedPause lets the director
    // distinguish a player-initiated pause (which it must not override) from
    // one it set itself during a coachmark. tickIntervalOverrideMs is read by
    // GameViewModel.applySpeed() to slow the tick rate during tutorial without
    // adding a player-visible speed button.
    var tutorialActive: Bool = false
    var activeTutorialStep: TutorialStep? = nil
    var tutorialSeenSteps: Set<TutorialStep> = []
    var tutorialOwnedPause: Bool = false
    var tickIntervalOverrideMs: Int? = nil

    // v9 Prompt 4 Phase 5 — total memory weight across all artifacts.
    // Rendered in the HUD top strip. Computed, not stored, so no extra
    // bookkeeping is required when memoryWeight is mutated in place.
    var totalMemoryWeight: Double {
        artifacts.reduce(0) { $0 + $1.memoryWeight }
    }

    // v9 — auto-dismiss toast queue. Replaced the Prompt 6 modal
    // ClosureEventCard (which required a Continue tap) with non-blocking
    // banners that fade in, hold for `Toast.duration`, and fade out
    // automatically. Closures, lawsuit outcomes, and other ephemeral
    // events all push here. The ledger remains the durable record.
    var toasts: [Toast] = []

    // v9 Prompt 6 — provenance ledger (data-only; Prompt 8 adds UI).
    // Monotonic; appended by TenantLifecycle on closure and by
    // StoreActions.acceptOffer when a memorial is destroyed. Never mutated
    // or truncated in-place.
    var ledger: [LedgerEntry] = []

    // v9 Prompt 7 — artifact id awaiting the Seal-confirmation overlay.
    // Non-nil → SealConfirmOverlay is mounted in MallView. Confirming
    // routes to ArtifactActions.sealStorefront; cancelling clears the id.
    var pendingSealConfirmationArtifactId: Int? = nil

    // v9 Prompt 8 — consecutive months in MallState.dead. Incremented per
    // tick while Mall.state == .dead; reset to 0 on any recovery. Drives
    // the ghostMall environmental state transition at
    // EnvironmentTuning.monthsInDeadForGhostMall (60 months / 5 years).
    var monthsInDeadState: Int = 0

    // v9 Prompt 9 Phase C — one-shot focus request from the ledger UI.
    // Set by GameViewModel.focusLedgerEntry when the tapped entry resolves
    // to a still-present artifact; MallScene.reconcileFocusRequest reads it,
    // runs the 2-second pulse, and calls vm.clearFocusRequest() to reset.
    // Nil in the common case.
    var pendingFocusArtifactId: Int? = nil

    // v9 Prompt 15 Phase 1 — transient per-tick economics trace.
    // Populated by TickEngine's economics step; consumed by MallScene's
    // reconcileEconomicsEvents to spawn floating +$N / -$N indicators
    // above the relevant source. Replaced (not appended) each tick, so
    // the array always represents the current month's cash flows.
    var lastTickEconomicsEvents: [EconomicsEvent] = []

    // v9 Prompt 14 — reason a run ended. Nil until `gameover` flips; then
    // either .bankruptcy (debt ceiling breached) or .forgotten (the mall
    // forgot itself — three-condition memory failure). Drives GameOverView
    // branching so the end-screen header and subtitle reflect how the
    // mall died.
    var gameOverReason: GameOverReason? = nil

    // v9 Prompt 14 — months in a row that currentTraffic has been below
    // FailureTuning.trafficFloor. Incremented each tick when traffic is
    // below floor; reset to 0 otherwise. Drives one of the three memory-
    // failure gates. Semantics are stricter than consecutiveLowTrafficMonths
    // (ratio-based, slow decrement) — this one resets cleanly on any tick
    // that meets the floor, since "the mall forgot itself" is a sustained-
    // neglect failure, not an occasionally-quiet one.
    var consecutiveMonthsBelowTrafficFloor: Int = 0

    // v9 patch — decision-sheet pause ownership. Mirrors tutorialOwnedPause:
    // the MANAGE drawer and the top-level Acquire sheet are decision
    // surfaces (not ambient), so they pause the game while open. Flag is
    // set when a sheet claims the pause (only if nothing else owns it);
    // cleared when that same sheet closes. If a tenant offer or tutorial
    // already owns the pause, the sheet hands off — closing it won't
    // resume prematurely.
    var decisionSheetOwnedPause: Bool = false

    // v9 Prompt 10 Phase A — anchor-departure cascade state.
    //
    // When an anchor closes, the wing it occupied enters a permanent
    // degraded state: traffic in that wing drops 25%, the wing's
    // environmental visual drops by one band relative to the mall-wide
    // state, and the non-anchor tenants in the wing receive a staggered
    // hardship cascade over 3 months.
    //
    // Phase A ships the DATA only. Phase C will consume wingEnvOffsets
    // for scene rendering; the resolver (Mall.wingEnvironmentState) is
    // wired in Phase A so consumers can ask the right question without
    // re-pattern-matching on the cascade state.

    // 25% traffic drop applies as a 0.75 multiplier to tr seen by in-wing
    // non-anchor tenants during the hardship calc in TickEngine. Keys are
    // set to 1.0 at game start (no drop); mutated to 0.75 on the
    // corresponding anchor's departure. Not reset — wing-level damage
    // from an anchor loss is permanent.
    var wingTrafficMultipliers: [Wing: Double] = [.north: 1.0, .south: 1.0]

    // Per-wing offset into EnvironmentState.allCases. 0 means the wing
    // renders at the mall-wide env state; 1 means one band darker; etc.
    // Mall.wingEnvironmentState(for:in:) applies this with clamping.
    // Permanent once set — the wing ages faster than the mall overall.
    var wingEnvOffsets: [Wing: Int] = [.north: 0, .south: 0]

    // Countdown of remaining hardship-cascade months for each wing.
    // Starts at 3 when the wing's anchor departs; decremented each tick
    // after the monthly cascade hardship is applied. When a wing's count
    // hits 0, the stagger is complete.
    var pendingWingHardshipMonths: [Wing: Int] = [.north: 0, .south: 0]

    // Set of wings whose anchors have departed at some point in the run.
    // Idempotency guard for the cascade: the spawn + field-set logic in
    // TenantLifecycle runs once per wing (the first time that wing's
    // anchor vacates). If an anchor could ever re-tenant and re-close
    // (not in current mechanics), this set prevents re-triggering the
    // cascade on the same wing.
    var anchorDepartedWings: Set<Wing> = []

    // v9 Prompt 10 Phase B — anchor departure modal card queue.
    //
    // Queue (not single slot) so concurrent anchor closures in the same
    // tick serialize — one card presents at a time, the next waits.
    // Appended by TenantLifecycle.vacateSlot in the anchor branch;
    // popped by GameViewModel.dismissAnchorDepartureCard on Continue.
    //
    // Render gate is `state.decision == nil && !queue.isEmpty` — if a
    // tenant-offer decision is active when an anchor cascade fires, the
    // anchor card waits behind it. One decision surface at a time.
    var anchorDepartureCardQueue: [AnchorDepartureCardPayload] = []

    // Pause ownership flag for the anchor-departure card. Mirrors
    // tutorialOwnedPause / decisionSheetOwnedPause: the card claims the
    // pause on .onAppear iff nothing else has paused the game, and
    // releases it only when the queue is empty AFTER pop. If a tenant
    // offer pause was active when the cascade fired, the card hands off
    // — ownership stays with the decision, and the card doesn't
    // clobber on dismiss.
    var anchorCardOwnedPause: Bool = false
}
