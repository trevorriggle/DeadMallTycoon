import XCTest
@testable import DeadMallTycoon

// v9 Prompt 9 Phase C coverage. Three layers:
//   - LedgerEntry.isPotentiallyTappable — UI-level flag (state-free).
//   - LedgerEntry.focusArtifactId(in:) — lookup against GameState.
//   - GameViewModel.focusLedgerEntry / clearFocusRequest — VM plumbing.
//
// Scene-layer pulse (MallScene.focusArtifact) is SpriteKit-only and not
// covered by unit tests; the VM sets state.pendingFocusArtifactId and
// the scene reads it during reconcile, which is wired but not executed
// in this test target.

// MARK: - Helpers

private func closure(year: Int = 1985, month: Int = 0,
                     name: String = "X", slotId: Int = 1,
                     tier: StoreTier = .standard) -> LedgerEntry {
    .closure(ClosureEvent(
        id: UUID(), tenantName: name, tenantTier: tier,
        yearsOpen: 1, slotId: slotId, year: year, month: month))
}

// MARK: - isPotentiallyTappable

final class LedgerEntryTappabilityTests: XCTestCase {

    func testTappableCasesReturnTrue() {
        let tappable: [LedgerEntry] = [
            closure(),
            .artifactCreated(artifactId: 1, name: "F", type: .fountain,
                              origin: .playerAction("placed"),
                              year: 1985, month: 0),
            .decayTransition(artifactId: 1, name: "F", type: .fountain,
                              fromCondition: 0, toCondition: 1,
                              year: 1985, month: 0),
            .attentionMilestone(artifactId: 1, name: "F", type: .fountain,
                                 threshold: 10, year: 1985, month: 0),
            .anchorDeparture(tenantName: "H", wing: .north,
                              trafficDelta: -300, coincidentClosureNames: [],
                              yearsOpen: 10, slotId: 1,
                              year: 1985, month: 0),
            .artifactSealed(tenantName: "X", sourceType: .boardedStorefront,
                             memoryWeight: 0, thoughtReferenceCount: 0,
                             year: 1985, month: 0),
            .displayConversion(tenantName: "X", content: .historicalPlaque,
                                memoryWeight: 0, thoughtReferenceCount: 0,
                                year: 1985, month: 0),
            .displayReverted(tenantName: "X", content: .historicalPlaque,
                              memoryWeight: 0, thoughtReferenceCount: 0,
                              year: 1985, month: 0),
        ]
        for entry in tappable {
            XCTAssertTrue(entry.isPotentiallyTappable,
                          "expected tappable: \(entry)")
        }
    }

    func testNonTappableCasesReturnFalse() {
        let nonTappable: [LedgerEntry] = [
            .offerDestruction(tenantName: "A", newTenantName: "B",
                               yearsBoarded: 1, memoryWeight: 0,
                               thoughtReferenceCount: 0,
                               year: 1985, month: 0),
            .artifactDestroyed(artifactId: 1, name: "F", type: .fountain,
                                reason: "flood", year: 1985, month: 0),
            .envTransition(from: .thriving, to: .fading,
                            year: 1985, month: 0),
        ]
        for entry in nonTappable {
            XCTAssertFalse(entry.isPotentiallyTappable,
                           "expected NON-tappable: \(entry)")
        }
    }
}

// MARK: - focusArtifactId(in:)

final class LedgerEntryFocusLookupTests: XCTestCase {

    // Direct-id cases (artifactCreated, decayTransition, attentionMilestone)
    // return the id iff the artifact is still in state.artifacts.

    func testDirectIdLookupReturnsIdWhenArtifactPresent() {
        var s = StartingMall.initialState()
        s.cash = 50_000
        s = ArtifactActions.place(type: .kugelBall, at: (x: 500, y: 700), s)
        let placedId = s.artifacts.last!.id

        let entry = LedgerEntry.decayTransition(
            artifactId: placedId, name: "Kugel Ball", type: .kugelBall,
            fromCondition: 0, toCondition: 1, year: s.year, month: s.month)
        XCTAssertEqual(entry.focusArtifactId(in: s), placedId)
    }

    func testDirectIdLookupReturnsNilWhenArtifactAbsent() {
        let s = StartingMall.initialState()
        let bogusEntry = LedgerEntry.decayTransition(
            artifactId: 99_999, name: "Missing", type: .kugelBall,
            fromCondition: 0, toCondition: 1, year: 1985, month: 0)
        XCTAssertNil(bogusEntry.focusArtifactId(in: s),
                     "no artifact with id 99,999 → nil")
    }

    // Slot-based lookup (.closure, .anchorDeparture): finds the memorial
    // sitting on the entry's slotId; most-recent id wins on tiebreak.

    func testClosureLookupResolvesToMemorialOnSameSlot() {
        var s = StartingMall.initialState()
        guard let storeIdx = s.stores.firstIndex(where: { $0.tier == .standard }) else {
            return XCTFail("no standard in starting seed?")
        }
        let slotId = s.stores[storeIdx].id
        s = TenantLifecycle.vacateSlot(storeIndex: storeIdx, state: s)
        let memorialId = s.artifacts.first { $0.storeSlotId == slotId }!.id

        guard case .closure(let ev) = s.ledger.first(where: { $0.isClosure })! else {
            return XCTFail()
        }
        XCTAssertEqual(LedgerEntry.closure(ev).focusArtifactId(in: s), memorialId)
    }

    func testAnchorDepartureLookupResolvesToMemorialOnSameSlot() {
        var s = StartingMall.initialState()
        guard let storeIdx = s.stores.firstIndex(where: { $0.tier == .anchor }) else {
            return XCTFail("no anchor in starting seed?")
        }
        let slotId = s.stores[storeIdx].id
        s = TenantLifecycle.vacateSlot(storeIndex: storeIdx, state: s)
        let memorialId = s.artifacts.first { $0.storeSlotId == slotId }!.id

        guard let entry = s.ledger.first(where: { $0.isAnchorDeparture }) else {
            return XCTFail()
        }
        XCTAssertEqual(entry.focusArtifactId(in: s), memorialId)
    }

    // Name-based lookup (.artifactSealed, .displayConversion, .displayReverted).
    // Fragile by design — documented trade-off for not adding a new
    // data field to those pre-Phase-A cases. Most-recent id wins on
    // same-name collisions.

    func testNameBasedLookupResolvesToMostRecentSameNameArtifact() {
        var s = StartingMall.initialState()
        // Close two slots with the same tenant name (synthetic case:
        // wouldn't happen in normal play, but exercises the tiebreak).
        let first  = s.stores.firstIndex(where: { $0.tier == .standard })!
        s.stores[first].name = "Duplicate"
        s = TenantLifecycle.vacateSlot(storeIndex: first, state: s)

        let second = s.stores.firstIndex(where: { $0.tier == .standard })!
        s.stores[second].name = "Duplicate"
        s = TenantLifecycle.vacateSlot(storeIndex: second, state: s)

        let duplicates = s.artifacts.filter { $0.name == "Duplicate" }
        XCTAssertEqual(duplicates.count, 2)
        let expectedId = duplicates.map(\.id).max()!

        let entry = LedgerEntry.artifactSealed(
            tenantName: "Duplicate", sourceType: .boardedStorefront,
            memoryWeight: 0, thoughtReferenceCount: 0,
            year: s.year, month: s.month)
        XCTAssertEqual(entry.focusArtifactId(in: s), expectedId,
                       "name-based lookup picks the highest-id matching artifact")
    }

    func testNameBasedLookupReturnsNilWhenNoMatch() {
        let s = StartingMall.initialState()
        let entry = LedgerEntry.displayConversion(
            tenantName: "Never Existed", content: .historicalPlaque,
            memoryWeight: 0, thoughtReferenceCount: 0,
            year: 1985, month: 0)
        XCTAssertNil(entry.focusArtifactId(in: s))
    }

    // Non-tappable cases always return nil regardless of state.

    func testNonTappableCasesAlwaysReturnNil() {
        let s = StartingMall.initialState()
        let cases: [LedgerEntry] = [
            .offerDestruction(tenantName: "A", newTenantName: "B",
                               yearsBoarded: 1, memoryWeight: 0,
                               thoughtReferenceCount: 0,
                               year: 1985, month: 0),
            .artifactDestroyed(artifactId: 1, name: "F", type: .fountain,
                                reason: "flood", year: 1985, month: 0),
            .envTransition(from: .thriving, to: .fading,
                            year: 1985, month: 0),
        ]
        for entry in cases {
            XCTAssertNil(entry.focusArtifactId(in: s),
                         "\(entry) should never resolve a focus target")
        }
    }
}

// MARK: - GameViewModel plumbing

final class GameViewModelFocusLedgerEntryTests: XCTestCase {

    func testFocusLedgerEntryOnPresentArtifactSetsPendingFocus() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.state.cash = 50_000
        vm.state = ArtifactActions.place(
            type: .kugelBall, at: (x: 500, y: 700), vm.state)
        let aid = vm.state.artifacts.last!.id

        let entry = LedgerEntry.attentionMilestone(
            artifactId: aid, name: "Kugel Ball", type: .kugelBall,
            threshold: 10, year: vm.state.year, month: vm.state.month)

        vm.focusLedgerEntry(entry)
        XCTAssertEqual(vm.state.pendingFocusArtifactId, aid)
        XCTAssertFalse(vm.state.toasts.contains(where: {
            $0.title.contains("no longer exists")
        }), "hit path does NOT push the missing-artifact toast")
    }

    func testFocusLedgerEntryOnMissingArtifactPushesToastAndLeavesPendingNil() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()

        let entry = LedgerEntry.decayTransition(
            artifactId: 99_999, name: "Missing", type: .fountain,
            fromCondition: 0, toCondition: 1,
            year: 1985, month: 0)
        vm.focusLedgerEntry(entry)
        XCTAssertNil(vm.state.pendingFocusArtifactId)
        XCTAssertTrue(vm.state.toasts.contains(where: {
            $0.title == "This artifact no longer exists."
        }), "miss path pushes the fallback toast")
    }

    func testFocusLedgerEntryOnNonTappableCaseAlsoPushesToastByDesign() {
        // Non-tappable cases should never reach VM.focusLedgerEntry
        // (rows don't wire a tap handler), but if they did, the VM's
        // resolve-or-toast logic treats them the same as a miss.
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.focusLedgerEntry(.envTransition(
            from: .thriving, to: .fading, year: 1985, month: 0))
        XCTAssertNil(vm.state.pendingFocusArtifactId)
        XCTAssertTrue(vm.state.toasts.contains(where: {
            $0.title == "This artifact no longer exists."
        }))
    }

    func testClearFocusRequestResetsPendingFocus() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.state.pendingFocusArtifactId = 42

        vm.clearFocusRequest()
        XCTAssertNil(vm.state.pendingFocusArtifactId)
    }
}
