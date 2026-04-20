import Foundation

// Guided first-year tutorial plumbing.
// New in the iOS port — v8.html has no onboarding system.
//
// One enum case per coachmark beat in the Jan–Dec 1982 script. Each beat fires
// at most once per run and is recorded in GameState.tutorialSeenSteps. The
// TutorialDirector (Phase 3) owns scheduling; this file is pure data.
enum TutorialStep: String, Codable, CaseIterable {
    case welcomeIntro    // Month 1 — paused welcome card
    case hud             // Month 1 — cash / score / threat arrows
    case corridor        // Month 2 — "tap a visitor" / "tap a store"
    case firstOffer      // Month 3 — first tenant decision framing
    case pnl             // Month 4–5 — monthly P&L explainer
    case watchList       // Month 6 — watch list (deferred if no hazard yet)
    case tabs            // Month 8 — bottom tab bar tour
    case scoreSources    // Month 10 — score breakdown panel
    case graduation      // Month 12 — tutorial exit, speed returns to x1

    // Most beats hide when a decision banner is active — the player is about to
    // make a choice and shouldn't be double-covered. .firstOffer is the exception:
    // it exists to frame the decision, so it renders above it.
    var showsOverDecision: Bool {
        self == .firstOffer
    }
}

// Logical UI anchors a coachmark can point at. Views publish their screen-space
// frame via .coachmarkAnchor(.cash); the CoachmarkOverlay (Phase 2) reads the
// collected dictionary and positions arrow + card.
//
// Adding a case here is cheap — the anchor only "exists" if some view publishes
// a frame for it. Unpublished anchors are silently absent from the dictionary.
enum CoachmarkAnchor: String, Hashable, CaseIterable {
    case cash            // HUD cash readout
    case score           // HUD score readout
    case threatMeter     // HUD threat bar
    case sceneVisitor    // mall scene — region containing visitors
    case sceneStore      // mall scene — region containing stores
    case pnlPanel        // monthly P&L display
    case watchList       // warnings / watch list panel
    case scoreSources    // score breakdown panel
    case tabBar          // bottom tab bar
}
