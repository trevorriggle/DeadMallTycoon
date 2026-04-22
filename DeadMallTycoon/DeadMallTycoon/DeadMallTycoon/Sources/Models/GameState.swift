import Foundation

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

    // v9 Prompt 6 — closure-event queue. Populated by TenantLifecycle.vacateSlot
    // on every tenant loss. Drives the ClosureEventCard overlay; the card
    // pops pendingClosureEvents.first on Continue. Silent queue: when
    // multiple closures arrive the same tick, only the front card renders
    // and the Continue button shows a small "N pending" badge.
    //
    // Deliberately NOT cleared by pause/speed changes — the cards are
    // narrative beats the player opts into, not interrupts.
    var pendingClosureEvents: [ClosureEvent] = []

    // v9 Prompt 6 — provenance ledger (data-only; Prompt 8 adds UI).
    // Monotonic; appended by TenantLifecycle on closure and by
    // StoreActions.acceptOffer when a memorial is destroyed. Never mutated
    // or truncated in-place.
    var ledger: [LedgerEntry] = []
}
