import Foundation

// Decides which tutorial beat (if any) should be visible right now, based on
// game state. Called after each tick and after each coachmark dismissal.
//
// Behavior:
//   - One beat active at a time (never interrupts a running beat).
//   - Beats yield to a decision, EXCEPT .firstOffer which specifically frames
//     the decision and renders above it.
//   - A beat whose trigger hasn't fired by year-end is skipped silently; we
//     never force a hazard or event into existence just to fire a beat.
//   - On entering year 1983 while the tutorial is still "active", we end it —
//     this is the silent-skip guard for any beats that never triggered.
//
// New in the iOS port — no v8 equivalent.
enum TutorialDirector {

    static func maybeFireNextBeat(_ state: GameState) -> GameState {
        var s = state
        guard s.tutorialActive else { return s }

        // Past year 1: tutorial auto-exits. The graduation beat normally fires
        // in December; this is the fallback if it never got a chance (e.g.
        // player was mid-decision when Dec ticked over).
        if s.year > GameConstants.startingYear {
            s.tutorialActive = false
            s.tickIntervalOverrideMs = nil
            s.activeTutorialStep = nil
            return s
        }

        // One beat at a time.
        guard s.activeTutorialStep == nil else { return s }

        guard let step = nextEligibleStep(s) else { return s }

        s.activeTutorialStep = step

        // Claim pause ownership only if we're the ones pausing. If the decision
        // was already pausing (as it does for .firstOffer), the decision's
        // accept/decline path owns unpausing.
        if !s.paused {
            s.paused = true
            s.tutorialOwnedPause = true
        } else {
            s.tutorialOwnedPause = false
        }
        return s
    }

    // Month mapping: spec's "Month N" = state.month == N-1 (state.month is 0=Jan).
    // >= rather than == so a beat that missed its window (because the player was
    // mid-decision or mid-coachmark) fires the next chance it gets.
    private static func nextEligibleStep(_ s: GameState) -> TutorialStep? {
        let seen = s.tutorialSeenSteps
        let month = s.month

        // firstOffer — runs OVER the tenant decision banner, not yielding to it.
        if !seen.contains(.firstOffer),
           month >= 2,
           case .tenant = s.decision {
            return .firstOffer
        }

        // All other beats yield to any pending decision.
        if s.decision != nil { return nil }

        // hud: right after welcome dismissed (still Jan = month 0).
        if !seen.contains(.hud) && seen.contains(.welcomeIntro) {
            return .hud
        }
        // corridor: Feb (month 1) or later.
        if !seen.contains(.corridor) && month >= 1 {
            return .corridor
        }
        // pnl: May (month 4) or later.
        if !seen.contains(.pnl) && month >= 4 {
            return .pnl
        }
        // watchList: Jul (month 6) or later, only once at least one hazard exists.
        // Deferred silently if no hazard is ever present in 1982.
        if !seen.contains(.watchList) && month >= 6 && hasHazard(s) {
            return .watchList
        }
        // tabs: Sep (month 8) or later.
        if !seen.contains(.tabs) && month >= 8 {
            return .tabs
        }
        // scoreSources: Nov (month 10) or later.
        if !seen.contains(.scoreSources) && month >= 10 {
            return .scoreSources
        }
        // graduation: Dec (month 11). Final beat — dismissCoachmark handles cleanup.
        if !seen.contains(.graduation) && month >= 11 {
            return .graduation
        }
        return nil
    }

    // v9 Prompt 3 — state.decorations removed; hazard sourced from unified artifacts.
    private static func hasHazard(_ s: GameState) -> Bool {
        s.artifacts.contains { $0.hazard }
    }
}
