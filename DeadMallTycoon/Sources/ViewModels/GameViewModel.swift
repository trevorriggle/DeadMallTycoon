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
    func startGame() {
        state = StartingMall.initialState()
        applySpeed()
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
              let ms = state.speed.tickIntervalMs else { return }
        let interval = TimeInterval(ms) / 1000.0
        ticker = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tickOnce()
        }
    }

    // v8: tick()
    func tickOnce() {
        state = TickEngine.tick(state, rng: &rng)
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

    func selectVisitor(_ id: UUID) {
        state.selectedVisitorId = id
        state.selectedStoreId = nil
        state.selectedDecorationId = nil
        if let v = state.visitors.first(where: { $0.id == id }) {
            let thought = PersonalityPicker.pickMemory(for: v, in: state, rng: &rng)
            state.selectedVisitorThought = thought
            state.thoughtsLog.insert(
                ThoughtLogEntry(visitorName: v.name, personality: v.personality, text: thought),
                at: 0
            )
            if state.thoughtsLog.count > 6 {
                state.thoughtsLog = Array(state.thoughtsLog.prefix(6))
            }
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
    func placeDecoration(kind: DecorationKind, at point: (x: Double, y: Double)) {
        state = DecorationActions.place(kind: kind, at: point, state)
    }
    func repairDecoration(_ id: Int) {
        state = DecorationActions.repair(decorationId: id, state)
    }
    func removeDecoration(_ id: Int) {
        state = DecorationActions.remove(decorationId: id, state)
    }
    func beginPlacement(_ kind: DecorationKind) {
        guard state.cash >= DecorationTypes.type(kind).cost else { return }
        state.placingDecoration = kind
    }
    func cancelPlacement() {
        state.placingDecoration = nil
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
