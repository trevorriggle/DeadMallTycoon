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
    // v9 Prompt 18 — tutorialEnabled is the player's opt-in from the
    // NewMallSheet. When true, the run starts with .welcome queued as
    // the first beat; the card pauses play until dismissed. When false,
    // the game enters live immediately — no welcome card, no detector
    // triggers. SC4 parity: a tutorialEnabled=false run must match a
    // pre-Prompt-18 run's state trajectory exactly.
    func startGame(tutorialEnabled: Bool) {
        state = StartingMall.initialState()
        state.tutorialEnabled = tutorialEnabled
        if tutorialEnabled {
            fireBeat(.welcome)
        }
        applySpeed()
    }

    // v9 Prompt 18 — beat trigger entry point. Idempotent per beat per
    // run (tutorialBeatsSeen gates). Called by:
    //   - TutorialBeatDetector.scan after each tick (detector-triggered
    //     beats: firstPlacement, firstTenantOffer, firstClosure, etc.)
    //   - View-layer hooks for UI-triggered beats (manageDrawer,
    //     firstLedgerView, firstVisitorThought)
    //
    // If nothing is currently on-screen the beat activates immediately
    // and claims the pause. If another beat card or a blocking decision
    // is active, the beat enqueues. Dismissal (see dismissTutorialBeat)
    // advances the queue.
    func fireBeat(_ beat: TutorialBeat) {
        guard state.tutorialEnabled else { return }
        guard !state.tutorialBeatsSeen.contains(beat) else { return }
        // Record immediately — the beat has "fired" the moment we
        // observe its trigger. Queue-vs-show is a presentation concern.
        state.tutorialBeatsSeen.insert(beat)
        if state.activeTutorialBeat == nil {
            state.activeTutorialBeat = beat
            claimTutorialBeatPause()
        } else {
            state.tutorialBeatQueue.append(beat)
        }
    }

    // Called by TutorialBeatCard.onAppear after the view mounts. The
    // view-side mount is what commits the pause; state.activeTutorialBeat
    // is set by fireBeat (or promoted here if a queued beat is being
    // displayed). Mirrors claimAnchorCardPause: only pause if nothing
    // else owns the paused state.
    private func claimTutorialBeatPause() {
        guard !state.paused else { return }
        state.paused = true
        state.tutorialBeatOwnedPause = true
    }

    // Called by the beat card's Continue button. Clears the active beat,
    // releases the pause IF we owned it, and promotes the next queued
    // beat (if any) — which re-claims the pause on its own .onAppear via
    // claimTutorialBeatPause.
    func dismissTutorialBeat() {
        guard state.activeTutorialBeat != nil else { return }
        state.activeTutorialBeat = nil
        if state.tutorialBeatOwnedPause {
            state.paused = false
            state.tutorialBeatOwnedPause = false
        }
        if !state.tutorialBeatQueue.isEmpty {
            let next = state.tutorialBeatQueue.removeFirst()
            state.activeTutorialBeat = next
            claimTutorialBeatPause()
        }
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
        let interval = TimeInterval(baseMs) / 1000.0
        ticker = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tickOnce()
        }
    }

    // v8: tick()
    // v9 Prompt 18 — after each engine tick, run TutorialBeatDetector to
    // queue any beats whose triggers fired. Detector is a no-op when
    // tutorialEnabled is false (SC4 parity).
    func tickOnce() {
        state = TickEngine.tick(state, rng: &rng)
        let triggered = TutorialBeatDetector.scan(state)
        for beat in triggered {
            fireBeat(beat)
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

        // v9 Prompt 18 — UI-triggered tutorial beat. Firing from inside
        // the selection path is the right coupling: the beat teaches
        // "visitor thoughts are a verb the game supports," and the
        // player has just done it.
        fireBeat(.firstVisitorThought)
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
    // Ownership semantics mirror tutorialBeatOwnedPause: claim the pause
    // only if nothing else owns it. If a tenant-offer decision, anchor
    // card, or tutorial beat is already paused when the sheet opens, we
    // hand off — the sheet closing will not clobber the other owner's
    // pause.
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

    // MARK: v9 Prompt 7 / Prompt 19 — seal confirmation flow

    // v9 Prompt 19 — unified request entrypoint for all three seal kinds.
    // Called from SealingSheet and (via requestSealConfirmation wrapper,
    // preserved for binary-minimal churn) ArtifactInfoCard. Opens the
    // SealConfirmOverlay; confirmSeal dispatches on the action's case.
    func requestSeal(_ action: SealAction) {
        state.pendingSealAction = action
    }

    // v9 Prompt 7 — preserved call signature for ArtifactInfoCard.
    // Thin wrapper over the generalized requestSeal(_:).
    func requestSealConfirmation(artifactId: Int) {
        requestSeal(.memorial(artifactId: artifactId))
    }

    func cancelSealConfirmation() {
        state.pendingSealAction = nil
    }

    // v9 Prompt 19 — dispatches on pendingSealAction. Memorial seals route
    // through ArtifactActions.sealStorefront (unchanged mutation path);
    // wing seals route through WingActions.toggleClosed (which already
    // handles the closed=true transition and clears downgrade); entrance
    // seals route through the new EntranceActions.seal. All three clear
    // pendingSealAction on completion.
    func confirmSeal() {
        guard let action = state.pendingSealAction else { return }
        switch action {
        case .memorial(let artifactId):
            state = ArtifactActions.sealStorefront(artifactId: artifactId, state)
        case .wing(let wing):
            // Only close if not already closed; toggleClosed would re-open
            // an already-closed wing. The sheet's eligibility filter prevents
            // this from happening in practice, but guard here defensively.
            if !(state.wingsClosed[wing] ?? false) {
                state = WingActions.toggleClosed(wing, state)
            }
        case .entrance(let corner):
            state = EntranceActions.seal(corner, state)
        }
        state.pendingSealAction = nil
        // v9 Prompt 19 — UI-triggered tutorial beat. Fires on the first
        // successful seal of ANY type. Wing and entrance seals don't
        // emit ledger entries that the post-tick detector could observe,
        // and gating ledger entries on tutorialEnabled would leak tutorial
        // flags into provenance data. fireBeat early-returns on
        // !tutorialEnabled so non-tutorial runs see zero effect here.
        fireBeat(.firstSealCompleted)
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
