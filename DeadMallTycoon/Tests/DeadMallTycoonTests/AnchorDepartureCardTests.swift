import XCTest
@testable import DeadMallTycoon

// v9 Prompt 10 Phase B coverage. Tests the card queue + VM pause plumbing.
// UI rendering (the card view itself, tap gestures, render-gate
// interaction with decision banners) is not unit-testable without a
// SwiftUI test harness; those land on manual playtest.
//
// Contracts pinned here:
//   - Anchor closure appends a payload; standard closure does NOT.
//   - Queue captures wing + yearsOpen correctly.
//   - dismissAnchorDepartureCard pops; releases pause only if owned
//     AND queue is empty after pop.
//   - claimAnchorCardPause hands off when another subsystem has the
//     pause (doesn't clobber tutorial / decision / drawer ownership).

// MARK: - Helpers

private func plantTenant(_ state: GameState, at slotId: Int,
                         name: String, tier: StoreTier = .standard,
                         traffic: Int = 60, threshold: Int = 30,
                         lease: Int = 24, monthsOccupied: Int = 36) -> GameState {
    var s = state
    guard let i = s.stores.firstIndex(where: { $0.id == slotId }) else { return s }
    let pos = s.stores[i].position
    s.stores[i] = Store(
        id: slotId, name: name, tier: tier,
        rent: 1000, originalRent: 1000, rentMultiplier: 1.0,
        traffic: traffic, threshold: threshold, lease: lease,
        hardship: 0, closing: false, leaving: false,
        monthsOccupied: monthsOccupied, monthsVacant: 0, promotionActive: false,
        position: pos
    )
    return s
}

// MARK: - Queue append

final class AnchorDepartureCardQueueTests: XCTestCase {

    func testAnchorClosureAppendsPayload() {
        var s = StartingMall.initialState()
        XCTAssertTrue(s.anchorDepartureCardQueue.isEmpty)
        guard let anchorIdx = s.stores.firstIndex(where: { $0.tier == .anchor }) else {
            return XCTFail("no anchor in starting seed")
        }
        let wing = s.stores[anchorIdx].wing
        let name = s.stores[anchorIdx].name
        s = TenantLifecycle.vacateSlot(storeIndex: anchorIdx, state: s)

        XCTAssertEqual(s.anchorDepartureCardQueue.count, 1)
        let payload = s.anchorDepartureCardQueue.first!
        XCTAssertEqual(payload.tenantName, name)
        XCTAssertEqual(payload.wing, wing)
    }

    func testStandardClosureDoesNotAppendPayload() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Brinkerhoff Books")
        s = TenantLifecycle.vacateSlot(storeIndex: 2, state: s)
        XCTAssertTrue(s.anchorDepartureCardQueue.isEmpty,
                      "non-anchor closures must not enqueue the modal card")
    }

    func testAnchorClosurePayloadCapturesYearsOpen() {
        var s = StartingMall.initialState()
        // Plant an anchor with a known monthsOccupied so yearsOpen is
        // pinned — starting seed uses monthsOccupied=0 which would yield 0.
        s = plantTenant(s, at: 1, name: "Halvorsen",
                        tier: .anchor, monthsOccupied: 120)
        s = TenantLifecycle.vacateSlot(storeIndex: 1, state: s)
        XCTAssertEqual(s.anchorDepartureCardQueue.first?.yearsOpen, 10,
                       "120 monthsOccupied → 10 yearsOpen")
    }
}

// MARK: - Pause claim / dismiss

final class AnchorCardPauseOwnershipTests: XCTestCase {

    func testClaimAnchorCardPauseFromIdleStateTakesOwnership() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        // Not paused by anything else yet.
        XCTAssertFalse(vm.state.paused)
        XCTAssertFalse(vm.state.anchorCardOwnedPause)

        vm.claimAnchorCardPause()
        XCTAssertTrue(vm.state.paused)
        XCTAssertTrue(vm.state.anchorCardOwnedPause)
    }

    func testClaimAnchorCardPauseHandsOffWhenAlreadyPaused() {
        // Mirror the "tenant offer active → anchor cascade fires" case:
        // something else owns the pause; card's onAppear must not
        // clobber that ownership.
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.state.paused = true   // simulate decision / tutorial owning it

        vm.claimAnchorCardPause()
        XCTAssertTrue(vm.state.paused)
        XCTAssertFalse(vm.state.anchorCardOwnedPause,
                       "if something else already owned pause, card doesn't claim")
    }

    func testDismissPopsQueueAndReleasesPauseWhenEmpty() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.state.anchorDepartureCardQueue.append(AnchorDepartureCardPayload(
            id: UUID(), tenantName: "Halvorsen", wing: .north, yearsOpen: 12))
        vm.claimAnchorCardPause()
        XCTAssertTrue(vm.state.paused)

        vm.dismissAnchorDepartureCard()
        XCTAssertTrue(vm.state.anchorDepartureCardQueue.isEmpty)
        XCTAssertFalse(vm.state.paused)
        XCTAssertFalse(vm.state.anchorCardOwnedPause)
    }

    func testDismissWithMoreCardsQueuedKeepsPauseHeld() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.state.anchorDepartureCardQueue = [
            AnchorDepartureCardPayload(id: UUID(), tenantName: "Halvorsen",
                                        wing: .north, yearsOpen: 12),
            AnchorDepartureCardPayload(id: UUID(), tenantName: "Pemberton",
                                        wing: .south, yearsOpen: 8),
        ]
        vm.claimAnchorCardPause()
        XCTAssertTrue(vm.state.paused)

        vm.dismissAnchorDepartureCard()
        XCTAssertEqual(vm.state.anchorDepartureCardQueue.count, 1,
                       "first card popped")
        XCTAssertEqual(vm.state.anchorDepartureCardQueue.first?.tenantName, "Pemberton")
        XCTAssertTrue(vm.state.paused,
                      "pause held while more cards queued")
        XCTAssertTrue(vm.state.anchorCardOwnedPause,
                      "ownership retained across pop when queue non-empty")
    }

    func testDismissWithoutOwnershipDoesNotReleaseAnotherOwnersPause() {
        // Card queued behind an active tenant-offer decision: card didn't
        // claim (paused was already true), so dismissing must NOT clobber
        // the decision's pause.
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.state.paused = true   // tenant offer owns it
        vm.state.anchorDepartureCardQueue.append(AnchorDepartureCardPayload(
            id: UUID(), tenantName: "Halvorsen", wing: .north, yearsOpen: 12))
        vm.claimAnchorCardPause()   // no-op; hands off
        XCTAssertFalse(vm.state.anchorCardOwnedPause)

        vm.dismissAnchorDepartureCard()
        XCTAssertTrue(vm.state.anchorDepartureCardQueue.isEmpty)
        XCTAssertTrue(vm.state.paused,
                      "external owner's pause preserved through dismiss")
    }

    func testDismissOnEmptyQueueIsNoOp() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.state.paused = false
        vm.dismissAnchorDepartureCard()   // shouldn't crash
        XCTAssertTrue(vm.state.anchorDepartureCardQueue.isEmpty)
        XCTAssertFalse(vm.state.paused)
    }
}

// MARK: - Flavor lookup

final class AnchorDepartureFlavorLookupTests: XCTestCase {

    func testKnownAnchorsReturnPerAnchorPlaceholder() {
        let halvorsen = AnchorDepartureFlavor.line(for: "Halvorsen")
        let pemberton = AnchorDepartureFlavor.line(for: "Pemberton")
        XCTAssertTrue(halvorsen.contains("Halvorsen"),
                      "placeholder explicitly names the anchor so authoring isn't guessed")
        XCTAssertTrue(pemberton.contains("Pemberton"))
    }

    func testUnknownAnchorFallsBackToGeneric() {
        let unknown = AnchorDepartureFlavor.line(for: "Impostor Anchor")
        XCTAssertTrue(unknown.contains("generic"),
                      "fallback placeholder is distinguishable from per-anchor entries")
    }

    func testEveryLookupReturnsNonEmpty() {
        // Contract from the AUTHORING TODO: placeholder strings stay
        // visible in UI. Never nil, never empty — the player sees
        // "[flavor pending: …]" which is legible signal of owed copy.
        XCTAssertFalse(AnchorDepartureFlavor.line(for: "Halvorsen").isEmpty)
        XCTAssertFalse(AnchorDepartureFlavor.line(for: "Pemberton").isEmpty)
        XCTAssertFalse(AnchorDepartureFlavor.line(for: "").isEmpty)
    }
}
