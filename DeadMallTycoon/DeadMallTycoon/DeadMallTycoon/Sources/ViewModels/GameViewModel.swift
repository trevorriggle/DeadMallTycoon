import Foundation
import Observation

// The one mutable seam between SwiftUI/SpriteKit and the pure logic layer.
// Owns the current GameState, the RNG, and the tick timer. Every player action
// is a pure function that returns a new state, which the VM assigns back.
@Observable
final class GameViewModel {

    var state: GameState

    @ObservationIgnored private var rng: SeededGenerator
    @ObservationIgnored private var ticker: Timer?

    // Deterministic seed so behavior can be reproduced. In production, pass a random seed.
    init(seed: UInt64 = UInt64.random(in: 1..<UInt64.max)) {
        self.rng = SeededGenerator(seed: seed)
        self.state = GameState()
    }

    // v8: startGame()
    // withTutorial=true enables the guided first-year tutorial: tick rate slows
    // to 8000ms, game starts paused on the welcome coachmark, director (Phase 3)
    // handles beat scheduling from there.
    func startGame(withTutorial: Bool = false) {
        state = StartingMall.initialState()
        if withTutorial {
            state.tutorialActive = true
            state.tickIntervalOverrideMs = 8000
            state.activeTutorialStep = .welcomeIntro
            state.paused = true
            state.tutorialOwnedPause = true
        }
        applySpeed()
    }

    // Called by the CoachmarkOverlay's Got-It button. Marks the active step as
    // seen, clears it, and — if the tutorial owned the pause — resumes play.
    func dismissCoachmark() {
        guard let step = state.activeTutorialStep else { return }
        state.tutorialSeenSteps.insert(step)
        state.activeTutorialStep = nil
        if state.tutorialOwnedPause {
            state.paused = false
            state.tutorialOwnedPause = false
        }
        // Graduation: tutorial is over, release the speed override and the flag.
        if step == .graduation {
            state.tutorialActive = false
            state.tickIntervalOverrideMs = nil
            applySpeed()
        }
        // Director may fire another beat immediately — e.g. .hud right after
        // .welcomeIntro is dismissed, while still in Jan (month 0).
        state = TutorialDirector.maybeFireNextBeat(state)
    }

    // v8: restart()
    func restart(seed: UInt64? = nil) {
        ticker?.invalidate(); ticker = nil
        if let seed { rng = SeededGenerator(seed: seed) }
        state = StartingMall.initialState()
        applySpeed()
    }

    // v8: setSpd(n)
    func setSpeed(_ speed: Speed) {
        state.speed = speed
        applySpeed()
    }

    private func applySpeed() {
        ticker?.invalidate(); ticker = nil
        guard !state.gameover, state.started,
              let baseMs = state.speed.tickIntervalMs else { return }
        // Tutorial-set override (e.g. 8000ms during year 1) wins over the player's
        // selected speed. Pause still wins over everything — speed.tickIntervalMs
        // is nil when paused, so we've already returned above in that case.
        let ms = state.tickIntervalOverrideMs ?? baseMs
        let interval = TimeInterval(ms) / 1000.0
        ticker = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tickOnce()
        }
    }

    // Called by the TutorialDirector (Phase 3). Pass an ms value to slow the
    // tick rate regardless of the player's selected Speed; pass nil to release
    // the override and return to the player's speed.
    func setTutorialSpeedOverride(_ ms: Int?) {
        state.tickIntervalOverrideMs = ms
        applySpeed()
    }

    // v8: tick()
    func tickOnce() {
        let prevOverrideMs = state.tickIntervalOverrideMs
        state = TickEngine.tick(state, rng: &rng)
        state = TutorialDirector.maybeFireNextBeat(state)
        // Director may have ended the tutorial on rollover to 1983, which
        // nils the override; reschedule the timer at the player's speed.
        if state.tickIntervalOverrideMs != prevOverrideMs {
            applySpeed()
        }
        if state.gameover {
            ticker?.invalidate(); ticker = nil
        }
    }

    // ---------- decision resolution ----------

    // v8: acceptTenant() / acceptEvent()
    func acceptDecision() {
        guard let d = state.decision else { return }
        switch d {
        case .tenant:
            state = StoreActions.acceptOffer(state)
        case .event(let ev):
            state = EventDeck.apply(ev, choice: .accept, state: state, rng: &rng)
            state.decision = nil
            state.paused = false
        }
    }

    // v8: declineTenant() / declineEvent()
    func declineDecision() {
        guard let d = state.decision else { return }
        switch d {
        case .tenant:
            state = StoreActions.declineOffer(state)
        case .event(let ev):
            state = EventDeck.apply(ev, choice: .decline, state: state, rng: &rng)
            state.decision = nil
            state.paused = false
        }
    }

    // ---------- selection ----------

    // Called by MallScene when a visitor sprite is tapped. The scene owns visitor
    // positions so it hands us the visitor object.
    func selectVisitor(_ visitor: Visitor) {
        state.selectedVisitorId = visitor.id
        state.selectedStoreId = nil
        state.selectedDecorationId = nil
        let thought = PersonalityPicker.pickMemory(for: visitor, in: state, rng: &rng)
        state.selectedVisitorThought = thought
        state.thoughtsLog.insert(
            ThoughtLogEntry(visitorName: visitor.name, personality: visitor.personality, text: thought),
            at: 0
        )
        if state.thoughtsLog.count > 6 {
            state.thoughtsLog = Array(state.thoughtsLog.prefix(6))
        }
    }

    func selectStore(_ id: Int) {
        state.selectedStoreId = id
        state.selectedVisitorId = nil
        state.selectedDecorationId = nil
    }

    func selectDecoration(_ id: Int) {
        state.selectedDecorationId = id
        state.selectedVisitorId = nil
        state.selectedStoreId = nil
    }

    func clearSelection() {
        state.selectedVisitorId = nil
        state.selectedStoreId = nil
        state.selectedDecorationId = nil
        state.selectedVisitorThought = ""
    }

    // ---------- player actions (thin pass-through to pure services) ----------

    func adjustRent(storeId: Int, delta: Double) {
        state = StoreActions.adjustRent(storeId: storeId, delta: delta, state)
    }
    func evictStore(_ id: Int) {
        state = StoreActions.evict(storeId: id, state)
    }
    func runStorePromo(_ id: Int) {
        state = StoreActions.runPromo(storeId: id, state)
    }
    func approachTenant(_ targetIndex: Int) -> Bool {
        let (newState, success) = StoreActions.approach(targetIndex: targetIndex, state, rng: &rng)
        state = newState
        return success
    }
    // v8: placeDecoration / repairDec / removeDec / beginPlacement / cancelPlacement
    // v9 Prompt 3 — routed through ArtifactActions on the unified Artifact model.
    // placingDecoration field renamed to placingArtifactType. selectedDecorationId
    // kept as-is (it now identifies the tapped Artifact; storage is the same).
    func placeArtifact(type: ArtifactType, at point: (x: Double, y: Double)) {
        state = ArtifactActions.place(type: type, at: point, state)
    }
    func repairArtifact(_ id: Int) {
        state = ArtifactActions.repair(artifactId: id, state)
    }
    func removeArtifact(_ id: Int) {
        state = ArtifactActions.remove(artifactId: id, state)
    }
    func beginPlacement(_ type: ArtifactType) {
        guard state.cash >= ArtifactCatalog.info(type).cost else { return }
        state.placingArtifactType = type
    }
    func cancelPlacement() {
        state.placingArtifactType = nil
    }
    func toggleWingClosed(_ wing: Wing) {
        state = WingActions.toggleClosed(wing, state)
    }
    func toggleWingDowngrade(_ wing: Wing) {
        state = WingActions.toggleDowngrade(wing, state)
    }
    func launchPromo(_ id: String) {
        state = PromoActions.launch(id, state)
    }
    func toggleAdDeal(_ id: String) {
        state = PromoActions.toggleAdDeal(id, state)
    }
    func toggleStaff(_ key: String) {
        state = PromoActions.toggleStaff(key, state)
    }
    func switchTab(_ tab: Tab) {
        state.currentTab = tab
    }
}
