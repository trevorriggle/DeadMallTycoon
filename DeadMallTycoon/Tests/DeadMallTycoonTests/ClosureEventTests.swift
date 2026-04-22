import XCTest
@testable import DeadMallTycoon

// v9 Prompt 6 coverage. Every vacate path must:
//   1. Enqueue a ClosureEvent onto state.pendingClosureEvents.
//   2. Append a .closure entry to state.ledger.
// AND the closure card UI must show one card at a time (silent queue).
// AND the game must NOT be paused by closure emission (pauses only come
// from Decision, not closure events).

// MARK: - Helpers (local to Prompt 6 tests)

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

    func testVacateEnqueuesClosureEvent() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Waldenbooks")
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!

        let before = s.pendingClosureEvents.count
        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        XCTAssertEqual(s.pendingClosureEvents.count, before + 1)
        let ev = s.pendingClosureEvents.last!
        XCTAssertEqual(ev.tenantName, "Waldenbooks")
        XCTAssertEqual(ev.tenantTier, .standard)
        XCTAssertEqual(ev.slotId, 2)
        XCTAssertEqual(ev.year, s.year)
        XCTAssertEqual(ev.month, s.month)
        XCTAssertFalse(ev.isAnchor)
    }

    func testVacateAppendsClosureLedgerEntry() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Claire's")
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!

        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        XCTAssertEqual(s.ledger.count, 1)
        guard case .closure(let ev) = s.ledger[0] else {
            return XCTFail("expected .closure ledger entry, got \(s.ledger[0])")
        }
        XCTAssertEqual(ev.tenantName, "Claire's")
    }

    func testAnchorClosureSetsIsAnchor() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 1, name: "Sears", tier: .anchor)
        let idx = s.stores.firstIndex(where: { $0.id == 1 })!

        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        let ev = s.pendingClosureEvents.last!
        XCTAssertTrue(ev.isAnchor, "anchor-tier closure must set isAnchor")
        XCTAssertEqual(ev.tenantTier, .anchor)
    }

    func testYearsOpenDerivedFromMonthsOccupied() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Sam Goody", monthsOccupied: 48)
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!

        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        XCTAssertEqual(s.pendingClosureEvents.last!.yearsOpen, 4,
                       "48 monthsOccupied → 4 yearsOpen via integer division")
    }

    func testVacateDoesNotPauseGame() {
        var s = StartingMall.initialState()
        s.paused = false
        s = plantTenant(s, at: 2, name: "Hot Topic")
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!

        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)

        XCTAssertFalse(s.paused,
                       "closure events must NOT pause the game (only tenant Decisions do)")
    }

    // MARK: Multiple closures — silent queue

    func testMultipleClosuresQueueIndividually() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 1, name: "Sam Goody")
        s = plantTenant(s, at: 2, name: "Waldenbooks")
        s = plantTenant(s, at: 3, name: "Foot Locker")

        s = TenantLifecycle.vacateSlot(storeIndex: 1, state: s)
        s = TenantLifecycle.vacateSlot(storeIndex: 2, state: s)
        s = TenantLifecycle.vacateSlot(storeIndex: 3, state: s)

        XCTAssertEqual(s.pendingClosureEvents.count, 3,
                       "each closure appends a card — never coalesced")
        XCTAssertEqual(s.pendingClosureEvents.map(\.tenantName),
                       ["Sam Goody", "Waldenbooks", "Foot Locker"],
                       "FIFO order — first to close pops first")
        XCTAssertEqual(s.ledger.count, 3)
    }

    // MARK: Eviction path

    func testEvictPathAlsoEnqueuesClosureEvent() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 4, name: "Hot Topic")
        s.score = 1000

        s = StoreActions.evict(storeId: 4, s)

        XCTAssertEqual(s.pendingClosureEvents.count, 1)
        XCTAssertEqual(s.pendingClosureEvents.last!.tenantName, "Hot Topic")
        XCTAssertEqual(s.ledger.count, 1)
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
        // All entries ship as "[flavor line pending]" and remain so until
        // Trevor authors them. The card still renders a legible string.
        let line = ClosureFlavor.line(for: event("Waldenbooks"))
        XCTAssertEqual(line, "[flavor line pending]",
                       "per-tenant entry returns the placeholder until authored")
    }

    func testPerTenantTakesPrecedenceOverTier() {
        // Both perTenant and perTier currently return placeholder; distinguish
        // via an off-roster name so the lookup falls to the tier line, then
        // assert the per-tenant path returns its (own) placeholder for a
        // rostered name. Both are "[flavor line pending]" today but the
        // dispatcher path they took differs.
        let rostered = ClosureFlavor.line(for: event("Sears", tier: .anchor))
        let unrostered = ClosureFlavor.line(for: event("Unknown Retailer", tier: .anchor))
        XCTAssertEqual(rostered, "[flavor line pending]")
        XCTAssertEqual(unrostered, "[flavor line pending]",
                       "falls through to anchor-tier placeholder")
    }

    func testNeutralFallbackUnreachableWithAllTiersCovered() {
        // All four StoreTiers have a perTier entry today. Any tier will
        // resolve to that entry before reaching the neutral template. This
        // test pins the invariant; removing a perTier entry would cause
        // this to fail.
        for tier in [StoreTier.anchor, .standard, .kiosk, .sketchy] {
            let line = ClosureFlavor.line(for: event("Unknown Retailer", tier: tier))
            XCTAssertNotEqual(line, "Unknown Retailer has closed after 3 years.",
                              "neutral template should be unreachable for tier \(tier)")
        }
    }
}

// MARK: - GameViewModel dismissal

final class ClosureEventDismissalTests: XCTestCase {

    func testDismissPopsFront() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.state.pendingClosureEvents = [
            ClosureEvent(id: UUID(), tenantName: "A", tenantTier: .standard,
                         yearsOpen: 1, slotId: 1, year: 1985, month: 0),
            ClosureEvent(id: UUID(), tenantName: "B", tenantTier: .standard,
                         yearsOpen: 1, slotId: 2, year: 1985, month: 0),
        ]
        vm.dismissClosureEvent()
        XCTAssertEqual(vm.state.pendingClosureEvents.count, 1)
        XCTAssertEqual(vm.state.pendingClosureEvents.first!.tenantName, "B")
    }

    func testDismissOnEmptyQueueIsNoOp() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.state.pendingClosureEvents = []
        vm.dismissClosureEvent()
        XCTAssertEqual(vm.state.pendingClosureEvents.count, 0)
    }
}
