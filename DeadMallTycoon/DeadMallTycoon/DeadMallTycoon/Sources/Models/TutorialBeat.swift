import Foundation

// v9 Prompt 18 — opt-in in-run tutorial beats.
//
// Philosophy: the old first-year coachmark sequence (Tutorial.swift + the
// TutorialDirector) tried to teach the UI in a scripted Jan–Dec 1982 walk.
// It ran off a month-indexed clock, interrupted the player repeatedly,
// and coupled lesson order to a prediction of what year one would look
// like. Prompt 18 replaces that scheme with a "beat sheet of moments":
// each beat has a natural trigger — the player did or saw a specific
// thing for the first time — and fires at most once per run. A beat never
// fabricates the moment; if the player never seals a wing, the
// .firstSealedWingSaving beat never appears. The run stays driven by the
// player.
//
// Two surfaces pause-and-card on trigger; the player taps Continue to
// resume. That's it. No coachmark arrows, no page-through, no anchor
// highlights. A single modal card reuses the AnchorDepartureCardView
// pause-composition pattern (tutorialBeatOwnedPause flag mirrors
// anchorCardOwnedPause / decisionSheetOwnedPause).
//
// The 19 beats approved for v9 — grouped by source of trigger. Order in
// this enum DOES NOT imply firing order at runtime; beats fire when their
// trigger fires, whenever that happens. CaseIterable is included purely
// for authoring/testing coverage checks (every case has copy, every case
// has a detector path).
enum TutorialBeat: String, Codable, CaseIterable {

    // Intro / orientation — fire on run start and first player verbs.
    case welcome                      // paused welcome card, before Jan 1982 begins
    case manageDrawer                 // first MANAGE drawer open
    case firstPlacement               // first artifact placed from Acquire
    case firstTenantOffer             // first tenant Decision banner shown
    case firstClosure                 // first tenant closure ledger entry
    case firstVisitorThought          // first time the player taps a visitor and reads a thought
    case firstLedgerView              // first History/ledger tab open

    // Memorial verbs — each fires the first time the player exercises it.
    case firstSeal                    // first boardedStorefront sealed
    case firstDisplay                 // first boardedStorefront converted to displaySpace

    // v9 Prompt 19 — sealing legibility beats. Three moments that make
    // sealing discoverable as the game's primary economic + memorial
    // verb. firstBoardedStorefront fires when the player first has a
    // closure memorial available to act on; firstWingEligibleForSealing
    // fires when a wing drops below 50% occupancy (the "sealing is now
    // a clear move" inflection); firstSealCompleted fires on the first
    // successful seal of ANY type (memorial, wing, or entrance) so the
    // player sees the payoff beat after the action, not before.
    case firstBoardedStorefront       // first .boardedStorefront in state.artifacts
    case firstWingEligibleForSealing  // first wing with < 50% non-vacant occupancy
    case firstSealCompleted           // first successful seal (any type)

    // Hazard + decay — fire on first time the player sees one.
    case firstHazard                  // first hazard artifact spawns on scene

    // Environmental ladder — fires on the first mall-wide env transition
    // (thriving → fading) AND a separate beat on first entering dying.
    case firstEnvTransition           // first env band crossed (any direction)
    case firstMallDying               // first time Mall.state == .dying

    // Economic legibility — fires when the player's sealed wings save
    // real cash on the operatingCost line (teaches that sealing is an
    // economic tool, not just a memorial verb). Detector checks the
    // post-tick ops reduction vs a baseline hypothetical with no sealed
    // wings.
    case firstSealedWingSaving

    // Action burst — fires when Scoring.actionBurst multiplier exceeds
    // 1.0 for the first time (teaches that rapid-sequence curation
    // compounds score).
    case firstActionBurst

    // Anchor cascade — fires the first time an anchor closes and the
    // cascade card queues up. The beat card renders BEFORE the anchor
    // card because .firstAnchorDeparture frames the cascade's meaning.
    case firstAnchorDeparture

    // Specialty / long-tenure tier — fires when the first specialty
    // tier offer appears in a decision.
    case firstSpecialtyOffer

    // Endgame framing — the three states that teach by happening.
    case firstMallDead                // first time Mall.state == .dead
    case approachingForgotten         // fires when FailureMode is within N months of trip
    case firstGhostMall               // first env transition INTO .ghostMall

    // A beat is "UI-triggered" if it fires when the player opens a
    // surface (drawer, ledger, visitor profile) rather than when the
    // tick engine observes a state change. UI-triggered beats are
    // fired by the view layer directly via GameViewModel.fireBeat.
    // Detector-triggered beats fire from TutorialBeatDetector.scan
    // after each tick. Split is informational — the same fireBeat
    // path handles both, with the same "only once per run" guard
    // against state.tutorialBeatsSeen.
    var isUITriggered: Bool {
        switch self {
        case .manageDrawer, .firstLedgerView, .firstVisitorThought,
             .firstSealCompleted:
            // v9 Prompt 19 — firstSealCompleted fires from the confirm
            // action (GameViewModel.confirmSeal), not from a post-tick
            // state scan. Wing and entrance seals don't emit ledger
            // entries that the detector could observe, and gating the
            // ledger on tutorialEnabled would leak tutorial flags into
            // provenance data. fireBeat(...) already early-returns on
            // !tutorialEnabled so non-tutorial runs stay untouched.
            return true
        default:
            return false
        }
    }
}
