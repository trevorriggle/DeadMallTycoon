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
    // withTutorial=true enables the guided first-year tutorial: game starts
    // paused on the welcome coachmark, director (Phase 3) handles beat
    // scheduling from there. The old tick-interval override (8000ms "half
    // speed" during year 1) was dropped with the v9 base-tick patch —
    // new 1x is already 8000ms, so the override had no remaining effect.
    func startGame(withTutorial: Bool = false) {
        state = StartingMall.initialState()
        if withTutorial {
            state.tutorialActive = true
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
        // Graduation: tutorial is over. The tickIntervalOverrideMs field is
        // no longer set by the tutorial (v9 patch dropped the override), but
        // we still clear it + re-apply speed as a defensive no-op in case
        // some future path sets an override.
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
        // tickIntervalOverrideMs is a kept seam for any future subsystem
        // that wants to slow the clock. v9 dropped the tutorial's use of
        // it (new 1x is already the slower pace); the override is currently
        // always nil in practice. Pause still wins over everything —
        // speed.tickIntervalMs is nil when paused, so we've already
        // returned above in that case.
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
    // v9 Prompt 4 Phase 2+3 — now fires a tagged Thought (via pickThought)
    // and, when the thought references an artifact, routes through
    // recordThoughtFired so memory weight accrues. Also stores the text as
    // before for the thought bubble + thoughts log.
    func selectVisitor(_ visitor: Visitor) {
        state.selectedVisitorId = visitor.id
        state.selectedStoreId = nil
        state.selectedDecorationId = nil

        let thought = PersonalityPicker.pickThought(
            for: visitor,
            at: (x: visitor.x, y: visitor.y),
            in: state, rng: &rng
        )
        state.selectedVisitorThought = thought.text
        state.thoughtsLog.insert(
            ThoughtLogEntry(visitorName: visitor.name, personality: visitor.personality, text: thought.text),
            at: 0
        )
        if state.thoughtsLog.count > 6 {
            state.thoughtsLog = Array(state.thoughtsLog.prefix(6))
        }

        // v9 Prompt 4 Phase 3 — memory weight accrual on tagged thoughts.
        if let artifactId = thought.artifactId {
            recordThoughtFired(artifactId: artifactId, cohort: visitor.ageCohort)
        }

        // v9 Prompt 4 Phase 6 — frozen identity snapshot for the profile panel.
        // Captures narrative state AT selection time. Subsequent passive
        // thoughts on this visitor do NOT mutate the snapshot (Prompt 4
        // non-goal: "panel shows state but does not modify it from player
        // actions").
        state.selectedVisitorIdentity = VisitorIdentity(from: visitor, memory: thought.text)
    }

    // v9 Prompt 4 Phase 2 — passive-thought path.
    // Called by MallScene's per-visitor thought timer (non-interactive, no
    // bubble UI). Generates a Thought for the visitor at their current
    // position; if tagged with an artifactId, applies memory weight; no
    // thoughts-log entry and no selectedVisitorThought mutation (silent).
    func firePassiveThought(for visitor: Visitor) {
        let thought = PersonalityPicker.pickThought(
            for: visitor,
            at: (x: visitor.x, y: visitor.y),
            in: state, rng: &rng
        )
        if let artifactId = thought.artifactId {
            recordThoughtFired(artifactId: artifactId, cohort: visitor.ageCohort)
        }
    }

    // v9 Prompt 4 Phase 3 — single place memory weight is incremented.
    // Base +0.5 × cohort multiplier (Originals 2.5, Nostalgics 1.5, Explorers 1.0).
    // Monotonic — never decreases in Prompt 4. Prompt 6 introduces the
    // destruction-on-vacancy-fill rule (see StoreActions.acceptOffer).
    //
    // v9 Prompt 6 — also increments thoughtReferenceCount (raw, uncohorted).
    // Surfaced in the memorial-cost line as "referenced in N visitor thoughts."
    //
    // v9 Prompt 7 — additionally multiplied by ArtifactType.memoryAccrualRate
    //   sealedStorefront → 0.5×   (less noticed, less remembered)
    //   displaySpace     → 1.5×   (curated, engages visitors more)
    //   everything else  → 1.0×
    // The Prompt-6 thoughtReferenceCount is NOT scaled — it stays a raw
    // count ("referenced in N thoughts" reads honestly).
    //
    // v9 Prompt 9 Phase A — emit .attentionMilestone when the post-
    // increment count lands exactly on a threshold in
    // LedgerEntry.attentionMilestoneThresholds. Each threshold fires at
    // most once per artifact because the count is monotonic and each
    // threshold is a single integer (count == 10, == 50, …).
    func recordThoughtFired(artifactId: Int, cohort: AgeCohort) {
        guard let idx = state.artifacts.firstIndex(where: { $0.id == artifactId }) else { return }
        let typeRate = state.artifacts[idx].type.memoryAccrualRate
        let increment = ThoughtTuning.memoryWeightBaseIncrement
                      * cohort.memoryWeightMultiplier
                      * typeRate
        state.artifacts[idx].memoryWeight += increment
        state.artifacts[idx].thoughtReferenceCount += 1
        // v9 Prompt 13 — reset decay counter. Any thought fire keeps the
        // artifact "lived-in"; TickEngine's memory decay only kicks in
        // once 6+ ticks pass without a hit.
        state.artifacts[idx].monthsSinceLastThought = 0

        let newCount = state.artifacts[idx].thoughtReferenceCount
        if LedgerEntry.attentionMilestoneThresholds.contains(newCount) {
            state.ledger.append(.attentionMilestone(
                artifactId: state.artifacts[idx].id,
                name: state.artifacts[idx].name,
                type: state.artifacts[idx].type,
                threshold: newCount,
                year: state.year,
                month: state.month
            ))
        }
    }

    // v9 — toast queue helpers. Pure state mutators; the view layer
    // schedules dismissal via .task {} after each toast's duration.
    func pushToast(_ toast: Toast) {
        state.toasts.append(toast)
    }

    func dismissToast(id: UUID) {
        state.toasts.removeAll { $0.id == id }
    }

    // MARK: v9 Prompt 9 Phase C — ledger tap-to-highlight

    // UI entry: called when the player taps a row in the History tab.
    // Resolves the entry against current state — if the referenced
    // artifact is still present, stash its id in pendingFocusArtifactId
    // for MallScene to pulse; otherwise push an informational toast.
    // Non-tappable entries (envTransition, offerDestruction, etc.)
    // shouldn't reach this path because the row won't wire a tap
    // handler, but the nil branch handles them safely.
    func focusLedgerEntry(_ entry: LedgerEntry) {
        if let aid = entry.focusArtifactId(in: state) {
            state.pendingFocusArtifactId = aid
        } else {
            pushToast(Toast(
                title: "This artifact no longer exists.",
                style: .info
            ))
        }
    }

    // Called by MallScene after it runs the pulse for a focus request.
    // Clears the pending id so the next tap (even of the same entry) is
    // observed as a fresh mutation and re-fires.
    func clearFocusRequest() {
        state.pendingFocusArtifactId = nil
    }

    // MARK: v9 patch — decision-sheet pause

    // Called by ManageDrawer.onAppear and ArtifactAcquireSheet.onAppear.
    // Both surfaces are decision contexts — the player is deciding what to
    // place or which tenant to pursue — so time must not advance while
    // they're open. Ambient surfaces (visitor profile panel, artifact info
    // card) do NOT call this.
    //
    // Ownership semantics mirror tutorialOwnedPause: claim the pause only
    // if nothing else owns it. If a tenant-offer decision or a tutorial
    // coachmark is already paused when the sheet opens, we hand off — the
    // sheet closing will not clobber the decision / tutorial's pause.
    func pauseForDecisionSheet() {
        guard !state.paused else { return }
        state.paused = true
        state.decisionSheetOwnedPause = true
    }

    // Called by ManageDrawer.onDisappear and ArtifactAcquireSheet.onDisappear.
    // Only releases the pause if this sheet claimed it.
    func resumeFromDecisionSheet() {
        guard state.decisionSheetOwnedPause else { return }
        state.paused = false
        state.decisionSheetOwnedPause = false
    }

    // MARK: v9 Prompt 10 Phase B — anchor departure modal card

    // Called when AnchorDepartureCardView.onAppear fires. Claims the
    // pause IF nothing else owns it; otherwise hands off — a tenant
    // offer (state.decision set, paused=true) or the tutorial still
    // owns the pause and the card just layers on top of the shared
    // paused state.
    func claimAnchorCardPause() {
        guard !state.paused else { return }
        state.paused = true
        state.anchorCardOwnedPause = true
    }

    // Called by the card's Continue button. Pops the current card off
    // the queue. If the queue is now empty AND we claimed the pause,
    // release it. If more cards are queued, leave pause held — the
    // next card's .onAppear will re-claim (but finds pause already
    // true, so it guards out cleanly — no flicker between cards).
    func dismissAnchorDepartureCard() {
        if !state.anchorDepartureCardQueue.isEmpty {
            state.anchorDepartureCardQueue.removeFirst()
        }
        if state.anchorDepartureCardQueue.isEmpty && state.anchorCardOwnedPause {
            state.paused = false
            state.anchorCardOwnedPause = false
        }
    }

    // MARK: v9 Prompt 7 — memorial verbs

    // UI entry: called from ArtifactInfoCard when the player taps Seal on a
    // boardedStorefront or displaySpace. Opens the SealConfirmOverlay; the
    // actual mutation happens in confirmSeal() after the player confirms.
    // Sealing is irreversible, so the extra tap is an intentional guard.
    func requestSealConfirmation(artifactId: Int) {
        state.pendingSealConfirmationArtifactId = artifactId
    }

    func cancelSealConfirmation() {
        state.pendingSealConfirmationArtifactId = nil
    }

    func confirmSeal() {
        guard let id = state.pendingSealConfirmationArtifactId else { return }
        state = ArtifactActions.sealStorefront(artifactId: id, state)
        state.pendingSealConfirmationArtifactId = nil
    }

    // UI entry: one-tap conversion from the inspector. Content variant is
    // chosen here via seeded rng; tests call ArtifactActions.repurposeAsDisplay
    // directly with a deterministic content argument.
    func repurposeAsDisplay(artifactId: Int) {
        let content = DisplayContent.allCases.randomElement(using: &rng) ?? .historicalPlaque
        state = ArtifactActions.repurposeAsDisplay(artifactId: artifactId, content: content, state)
    }

    func revertToBoarded(artifactId: Int) {
        state = ArtifactActions.revertToBoarded(artifactId: artifactId, state)
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
        state.selectedVisitorIdentity = nil   // v9 Prompt 4 Phase 6
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
