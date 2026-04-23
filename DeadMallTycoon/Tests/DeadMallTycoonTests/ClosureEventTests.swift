import XCTest
@testable import DeadMallTycoon

// v9 Prompt 6 + auto-dismiss patch coverage. Every vacate path must:
//   1. Append a .closure entry to state.ledger (durable record).
//   2. Append a Toast (style: .closure) to state.toasts (player awareness).
// Game must NOT pause.

// MARK: - Helpers (local to these tests)

private func plantTenant(_ state: GameState, at slotId: Int,
                         name: String, tier: StoreTier = .standard,
                         monthsOccupied: Int = 36) -> GameState {
    var s = state
    guard let i = s.stores.firstIndex(where: { $0.id == slotId }) else { return s }
    let pos = s.stores[i].position
    s.stores[i] = Store(
        id: slotId, name: name, tier: tier,
        rent: 1000, originalRent: 1000, rentMultiplier: 1.0,
        traffic: 60, threshold: 30, lease: 24,
        hardship: 0, closing: false, leaving: false,
        monthsOccupied: monthsOccupied, monthsVacant: 0, promotionActive: false,
        position: pos
    )
    return s
}

final class ClosureEventEmissionTests: XCTestCase {

    // MARK: Direct TenantLifecycle

    func testVacateAppendsClosureLedgerEntry() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Lulu & Lace")
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!

        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        XCTAssertEqual(s.ledger.count, 1)
        guard case .closure(let ev) = s.ledger[0] else {
            return XCTFail("expected .closure ledger entry, got \(s.ledger[0])")
        }
        XCTAssertEqual(ev.tenantName, "Lulu & Lace")
        XCTAssertEqual(ev.tenantTier, .standard)
        XCTAssertEqual(ev.slotId, 2)
        XCTAssertEqual(ev.year, s.year)
        XCTAssertEqual(ev.month, s.month)
        XCTAssertFalse(ev.isAnchor)
    }

    func testVacatePushesClosureToast() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Brinkerhoff Books")
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!

        let before = s.toasts.count
        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        XCTAssertEqual(s.toasts.count, before + 1)
        let toast = s.toasts.last!
        XCTAssertEqual(toast.title, "Brinkerhoff Books",
                       "closure toast title is the retailer name")
        XCTAssertEqual(toast.style, .closure)
        XCTAssertNotNil(toast.subtitle, "closure flavor line lives in subtitle")
    }

    func testAnchorClosureLedgerEntryRecordsAnchorTier() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 1, name: "Halvorsen", tier: .anchor)
        let idx = s.stores.firstIndex(where: { $0.id == 1 })!

        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        guard case .closure(let ev) = s.ledger.last! else {
            return XCTFail("expected .closure ledger entry")
        }
        XCTAssertTrue(ev.isAnchor)
        XCTAssertEqual(ev.tenantTier, .anchor)
    }

    func testYearsOpenDerivedFromMonthsOccupied() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Ricky's Records", monthsOccupied: 48)
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!

        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        guard case .closure(let ev) = s.ledger.last! else {
            return XCTFail("expected .closure ledger entry")
        }
        XCTAssertEqual(ev.yearsOpen, 4,
                       "48 monthsOccupied → 4 yearsOpen via integer division")
    }

    func testVacateDoesNotPauseGame() {
        var s = StartingMall.initialState()
        s.paused = false
        s = plantTenant(s, at: 2, name: "Razor & Rose")
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!

        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        XCTAssertFalse(s.paused,
                       "closure events must NOT pause the game (only tenant Decisions do)")
    }

    // MARK: Multiple closures — independent toasts + ledger entries

    func testMultipleClosuresStackToasts() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 1, name: "Ricky's Records")
        s = plantTenant(s, at: 2, name: "Brinkerhoff Books")
        s = plantTenant(s, at: 3, name: "Sole Center")

        s = TenantLifecycle.vacateSlot(storeIndex: 1, state: s)
        s = TenantLifecycle.vacateSlot(storeIndex: 2, state: s)
        s = TenantLifecycle.vacateSlot(storeIndex: 3, state: s)

        XCTAssertEqual(s.ledger.count, 3, "each closure writes its own ledger entry")
        // Toast queue gains three closures, in chronological order.
        let closureToasts = s.toasts.filter { $0.style == .closure }
        XCTAssertEqual(closureToasts.count, 3)
        XCTAssertEqual(closureToasts.map(\.title),
                       ["Ricky's Records", "Brinkerhoff Books", "Sole Center"])
    }

    // MARK: Eviction path

    func testEvictPathAlsoEmitsClosure() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 4, name: "Razor & Rose")
        s.score = 1000

        s = StoreActions.evict(storeId: 4, s)

        XCTAssertEqual(s.ledger.count, 1)
        let closureToasts = s.toasts.filter { $0.style == .closure }
        XCTAssertEqual(closureToasts.last?.title, "Razor & Rose")
    }
}

// MARK: - ClosureFlavor lookup

final class ClosureFlavorLookupTests: XCTestCase {

    private func event(_ name: String, tier: StoreTier = .standard,
                       yearsOpen: Int = 3) -> ClosureEvent {
        ClosureEvent(id: UUID(), tenantName: name, tenantTier: tier,
                     yearsOpen: yearsOpen, slotId: 1, year: 1985, month: 0)
    }

    func testPerTenantLookupReturnsPlaceholderWhilePending() {
        let line = ClosureFlavor.line(for: event("Brinkerhoff Books"))
        XCTAssertEqual(line, "[flavor line pending]",
                       "per-tenant entry returns the placeholder until authored")
    }

    func testPerTenantTakesPrecedenceOverTier() {
        let rostered = ClosureFlavor.line(for: event("Halvorsen", tier: .anchor))
        let unrostered = ClosureFlavor.line(for: event("Unknown Retailer", tier: .anchor))
        XCTAssertEqual(rostered, "[flavor line pending]")
        XCTAssertEqual(unrostered, "[flavor line pending]",
                       "falls through to anchor-tier placeholder")
    }

    func testNeutralFallbackUnreachableWithAllTiersCovered() {
        for tier in [StoreTier.anchor, .standard, .kiosk, .sketchy] {
            let line = ClosureFlavor.line(for: event("Unknown Retailer", tier: tier))
            XCTAssertNotEqual(line, "Unknown Retailer has closed after 3 years.",
                              "neutral template should be unreachable for tier \(tier)")
        }
    }
}

// MARK: - Toast queue (v9 patch)

final class ToastQueueTests: XCTestCase {

    func testPushToastAppendsToState() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.pushToast(Toast(title: "Hi", style: .info))
        XCTAssertEqual(vm.state.toasts.count, 1)
    }

    func testDismissToastRemovesById() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        let a = Toast(title: "A", style: .info)
        let b = Toast(title: "B", style: .info)
        vm.pushToast(a)
        vm.pushToast(b)
        vm.dismissToast(id: a.id)
        XCTAssertEqual(vm.state.toasts.count, 1)
        XCTAssertEqual(vm.state.toasts.first?.title, "B")
    }

    func testDismissUnknownIdIsNoOp() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.pushToast(Toast(title: "A", style: .info))
        vm.dismissToast(id: UUID())
        XCTAssertEqual(vm.state.toasts.count, 1)
    }

    func testDefaultDurationsByStyle() {
        XCTAssertEqual(Toast(title: "x", style: .info).duration,    2.5)
        XCTAssertEqual(Toast(title: "x", style: .closure).duration, 5.0)
        XCTAssertEqual(Toast(title: "x", style: .victory).duration, 3.0)
        XCTAssertEqual(Toast(title: "x", style: .loss).duration,    3.5)
    }
}

// MARK: - Lawsuit outcome toasts (v9 patch)

final class LawsuitOutcomeToastTests: XCTestCase {

    private func lawsuitDecision() -> Decision {
        .event(EventDeck.openingLawsuit())
    }

    func testAcceptPushesSettledInfoToast() {
        var s = StartingMall.initialState()
        s.cash = 10_000
        s.decision = lawsuitDecision()
        var rng = SeededGenerator(seed: 1)
        guard case .event(let ev) = s.decision! else { return XCTFail() }

        s = EventDeck.apply(ev, choice: .accept, state: s, rng: &rng)
        let infoToasts = s.toasts.filter { $0.style == .info }
        XCTAssertEqual(infoToasts.count, 1)
        XCTAssertTrue(infoToasts.first!.title.uppercased().contains("SETTLED"))
    }

    func testDeclineWinPushesVictoryToast() {
        // Deterministic seed where rng.chance(0.5) returns false (no charge).
        var s = StartingMall.initialState()
        s.cash = 10_000
        s.decision = lawsuitDecision()
        guard case .event(let ev) = s.decision! else { return XCTFail() }

        // Try seeds until we land on the favorable branch; brute-force is fine
        // since .chance is deterministic per seed.
        var foundVictory = false
        for seed in UInt64(1)...UInt64(50) {
            var rng = SeededGenerator(seed: seed)
            let testS = EventDeck.apply(ev, choice: .decline, state: s, rng: &rng)
            if testS.toasts.contains(where: { $0.style == .victory }) {
                foundVictory = true
                XCTAssertEqual(testS.cash, 10_000,
                               "victory branch must not deduct cash")
                break
            }
        }
        XCTAssertTrue(foundVictory, "at least one seed in 1..50 should hit the victory branch")
    }

    func testDeclineLossPushesLossToast() {
        var s = StartingMall.initialState()
        s.cash = 10_000
        s.decision = lawsuitDecision()
        guard case .event(let ev) = s.decision! else { return XCTFail() }

        var foundLoss = false
        for seed in UInt64(1)...UInt64(50) {
            var rng = SeededGenerator(seed: seed)
            let testS = EventDeck.apply(ev, choice: .decline, state: s, rng: &rng)
            if testS.toasts.contains(where: { $0.style == .loss }) {
                foundLoss = true
                XCTAssertEqual(testS.cash, 10_000 - 5_000,
                               "loss branch deducts $5,000")
                break
            }
        }
        XCTAssertTrue(foundLoss, "at least one seed in 1..50 should hit the loss branch")
    }
}
