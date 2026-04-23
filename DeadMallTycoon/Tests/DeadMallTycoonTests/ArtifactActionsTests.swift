import XCTest
@testable import DeadMallTycoon

// v9 Prompt 7 coverage. Three memorial verbs — Seal, Repurpose as Display,
// Revert to Boarded — plus the downstream side effects (offer-pool
// exclusion, operating-cost deltas, memory-accrual rate shifts, ledger).

// MARK: - Helpers

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

// Close a tenant on slot N and return state + the spawned boardedStorefront's id.
private func closeTenant(in state: GameState, at slotId: Int, name: String) -> (GameState, Int) {
    var s = plantTenant(state, at: slotId, name: name)
    let idx = s.stores.firstIndex(where: { $0.id == slotId })!
    s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)
    let artifactId = s.artifacts.first { $0.storeSlotId == slotId }!.id
    return (s, artifactId)
}

private let standardOffer = TenantOffer(
    name: "GameVault", tier: .standard, rent: 750, traffic: 50,
    threshold: 25, lease: 24, pitch: "Teen traffic."
)

// MARK: - Seal

final class SealStorefrontTests: XCTestCase {

    func testSealMutatesBoardedToSealed() {
        let (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Brinkerhoff Books")
        let after = ArtifactActions.sealStorefront(artifactId: aid, state)
        let a = after.artifacts.first { $0.id == aid }!
        XCTAssertEqual(a.type, .sealedStorefront)
        XCTAssertNil(a.displayContent)
    }

    func testSealPreservesMemorialProvenance() {
        var (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Lulu & Lace")
        // Seed some weight to verify preservation.
        if let idx = state.artifacts.firstIndex(where: { $0.id == aid }) {
            state.artifacts[idx].memoryWeight = 12.5
            state.artifacts[idx].thoughtReferenceCount = 4
            state.artifacts[idx].condition = 2
        }

        let after = ArtifactActions.sealStorefront(artifactId: aid, state)
        let a = after.artifacts.first { $0.id == aid }!
        XCTAssertEqual(a.id, aid, "same artifact id — no new instance")
        XCTAssertEqual(a.memoryWeight, 12.5, "memory weight preserved through conversion")
        XCTAssertEqual(a.thoughtReferenceCount, 4, "thought ref count preserved")
        XCTAssertEqual(a.condition, 2, "condition preserved")
    }

    // CRITICAL INVARIANT — seal removes the slot from the offer pool.
    func testSealRemovesSlotFromOfferPool() {
        let (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Ricky's Records")
        XCTAssertNotNil(StoreActions.prospectiveSlotIndex(for: standardOffer, in: state),
                        "precondition: boardedStorefront slot is in the pool")
        let after = ArtifactActions.sealStorefront(artifactId: aid, state)
        let idx = StoreActions.prospectiveSlotIndex(for: standardOffer, in: after)
        // The offer picker can still land on the other starting vacant; the
        // specific slot we sealed must NOT be the answer.
        if let i = idx {
            XCTAssertNotEqual(after.stores[i].id, 2,
                              "sealed slot must not be returned by prospectiveSlotIndex")
        }
    }

    func testSealZeroesVacancyPenalty() {
        let (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Razor & Rose")
        let costBefore = Economy.operatingCost(state)
        let after = ArtifactActions.sealStorefront(artifactId: aid, state)
        let costAfter = Economy.operatingCost(after)
        XCTAssertEqual(costBefore - costAfter, 350,
                       "sealing one slot drops the monthly vacancy penalty by exactly $350")
    }

    func testSealWritesLedgerEntry() {
        let (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Brinkerhoff Books")
        let ledgerBefore = state.ledger.count
        let after = ArtifactActions.sealStorefront(artifactId: aid, state)
        XCTAssertEqual(after.ledger.count, ledgerBefore + 1)
        guard case .artifactSealed(let name, let src, _, _, _, _) = after.ledger.last! else {
            return XCTFail("expected .artifactSealed ledger entry")
        }
        XCTAssertEqual(name, "Brinkerhoff Books")
        XCTAssertEqual(src, .boardedStorefront)
    }

    func testSealFromDisplayAlsoWorks() {
        var (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Sole Center")
        state = ArtifactActions.repurposeAsDisplay(artifactId: aid,
                                                    content: .communityArt, state)
        let after = ArtifactActions.sealStorefront(artifactId: aid, state)
        XCTAssertEqual(after.artifacts.first { $0.id == aid }!.type, .sealedStorefront)
        if case .artifactSealed(_, let src, _, _, _, _) = after.ledger.last! {
            XCTAssertEqual(src, .displaySpace,
                           "sourceType records the displaySpace origin")
        } else {
            XCTFail("expected .artifactSealed")
        }
    }

    func testSealOnNonEligibleArtifactIsNoOp() {
        let state = StartingMall.initialState()
        // Grab a pre-placed decoration (e.g., the kugel ball at id 0).
        let kugelId = state.artifacts.first { $0.type == .kugelBall }!.id
        let after = ArtifactActions.sealStorefront(artifactId: kugelId, state)
        XCTAssertEqual(after, state, "seal on decoration must leave state unchanged")
    }
}

// MARK: - Repurpose as Display

final class RepurposeAsDisplayTests: XCTestCase {

    func testRepurposeMutatesBoardedToDisplay() {
        let (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Brinkerhoff Books")
        let after = ArtifactActions.repurposeAsDisplay(artifactId: aid,
                                                        content: .vintageMallPhotos, state)
        let a = after.artifacts.first { $0.id == aid }!
        XCTAssertEqual(a.type, .displaySpace)
        XCTAssertEqual(a.displayContent, .vintageMallPhotos)
    }

    func testRepurposePopulatesThoughtPoolFromContent() {
        let (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Ricky's Records")
        let after = ArtifactActions.repurposeAsDisplay(artifactId: aid,
                                                        content: .historicalPlaque, state)
        let a = after.artifacts.first { $0.id == aid }!
        XCTAssertEqual(a.thoughtTriggers, DisplayContent.historicalPlaque.thoughtPool,
                       "thought triggers must come from the chosen content variant")
    }

    // CRITICAL INVARIANT — repurpose removes the slot from the offer pool.
    func testRepurposeRemovesSlotFromOfferPool() {
        let (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Brinkerhoff Books")
        XCTAssertNotNil(StoreActions.prospectiveSlotIndex(for: standardOffer, in: state))
        let after = ArtifactActions.repurposeAsDisplay(artifactId: aid,
                                                        content: .seasonalVignette, state)
        let idx = StoreActions.prospectiveSlotIndex(for: standardOffer, in: after)
        if let i = idx {
            XCTAssertNotEqual(after.stores[i].id, 2,
                              "display-converted slot must not be returned by prospectiveSlotIndex")
        }
    }

    func testRepurposeAddsMaintenanceCost() {
        let (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Razor & Rose")
        let costBefore = Economy.operatingCost(state)
        let after = ArtifactActions.repurposeAsDisplay(artifactId: aid,
                                                        content: .localArtistShowcase, state)
        let costAfter = Economy.operatingCost(after)
        // The slot was already vacant ($350 penalty already accounted for).
        // Converting to display keeps the $350 penalty AND adds $75 maintenance.
        XCTAssertEqual(costAfter - costBefore, 75,
                       "display conversion adds $75/mo maintenance")
    }

    func testRepurposeWritesLedgerEntry() {
        let (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Lulu & Lace")
        let after = ArtifactActions.repurposeAsDisplay(artifactId: aid,
                                                        content: .communityArt, state)
        guard case .displayConversion(let name, let content, _, _, _, _) = after.ledger.last! else {
            return XCTFail("expected .displayConversion")
        }
        XCTAssertEqual(name, "Lulu & Lace")
        XCTAssertEqual(content, .communityArt)
    }

    func testRepurposeOnNonBoardedIsNoOp() {
        let state = StartingMall.initialState()
        // Try on a decoration.
        let fountainId = state.artifacts.first { $0.type == .fountain }!.id
        let after = ArtifactActions.repurposeAsDisplay(artifactId: fountainId,
                                                        content: .historicalPlaque, state)
        XCTAssertEqual(after, state)
    }

    func testRepurposeOnSealedIsNoOp() {
        var (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Brinkerhoff Books")
        state = ArtifactActions.sealStorefront(artifactId: aid, state)
        let after = ArtifactActions.repurposeAsDisplay(artifactId: aid,
                                                        content: .vintageMallPhotos, state)
        XCTAssertEqual(after, state,
                       "seal is terminal; repurpose must NOT unseal")
    }
}

// MARK: - Revert

final class RevertToBoardedTests: XCTestCase {

    func testRevertMutatesDisplayToBoarded() {
        var (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Brinkerhoff Books")
        state = ArtifactActions.repurposeAsDisplay(artifactId: aid,
                                                   content: .vintageMallPhotos, state)
        let after = ArtifactActions.revertToBoarded(artifactId: aid, state)
        let a = after.artifacts.first { $0.id == aid }!
        XCTAssertEqual(a.type, .boardedStorefront)
        XCTAssertNil(a.displayContent)
    }

    func testRevertRemovesMaintenanceCost() {
        var (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Ricky's Records")
        state = ArtifactActions.repurposeAsDisplay(artifactId: aid,
                                                   content: .historicalPlaque, state)
        let displayCost = Economy.operatingCost(state)
        let after = ArtifactActions.revertToBoarded(artifactId: aid, state)
        let boardedCost = Economy.operatingCost(after)
        XCTAssertEqual(displayCost - boardedCost, 75,
                       "revert drops the $75 maintenance line")
    }

    func testRevertRestoresOfferPoolEligibility() {
        var (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Razor & Rose")
        state = ArtifactActions.repurposeAsDisplay(artifactId: aid,
                                                   content: .communityArt, state)
        let after = ArtifactActions.revertToBoarded(artifactId: aid, state)
        // Slot 2 should again be a valid target for a standard offer.
        // Since slot 2 is earlier in positions order than the original vacants,
        // prospectiveSlotIndex should pick it.
        let idx = StoreActions.prospectiveSlotIndex(for: standardOffer, in: after)
        XCTAssertNotNil(idx)
        XCTAssertEqual(after.stores[idx!].id, 2,
                       "reverted slot should return to the offer pool")
    }

    func testRevertWritesLedgerEntry() {
        var (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Lulu & Lace")
        state = ArtifactActions.repurposeAsDisplay(artifactId: aid,
                                                   content: .communityArt, state)
        let after = ArtifactActions.revertToBoarded(artifactId: aid, state)
        guard case .displayReverted(let name, let content, _, _, _, _) = after.ledger.last! else {
            return XCTFail("expected .displayReverted")
        }
        XCTAssertEqual(name, "Lulu & Lace")
        XCTAssertEqual(content, .communityArt, "records the content that was abandoned")
    }

    func testRevertOnBoardedIsNoOp() {
        let (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Brinkerhoff Books")
        let after = ArtifactActions.revertToBoarded(artifactId: aid, state)
        XCTAssertEqual(after, state)
    }

    func testRevertOnSealedIsNoOp() {
        var (state, aid) = closeTenant(in: StartingMall.initialState(),
                                        at: 2, name: "Brinkerhoff Books")
        state = ArtifactActions.sealStorefront(artifactId: aid, state)
        let after = ArtifactActions.revertToBoarded(artifactId: aid, state)
        XCTAssertEqual(after, state)
    }
}

// MARK: - Memory accrual rate

final class MemoryAccrualRateTests: XCTestCase {

    func testAccrualRateConstants() {
        XCTAssertEqual(ArtifactType.boardedStorefront.memoryAccrualRate, 1.0)
        XCTAssertEqual(ArtifactType.sealedStorefront.memoryAccrualRate, 0.5)
        XCTAssertEqual(ArtifactType.displaySpace.memoryAccrualRate, 1.5)
        XCTAssertEqual(ArtifactType.kugelBall.memoryAccrualRate, 1.0,
                       "decoration types stay at 1.0 baseline")
    }

    func testRecordThoughtFiredAppliesTypeRate() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        // Close three tenants so we have a clean boardedStorefront to manipulate.
        let (s1, boardedId) = closeTenant(in: vm.state, at: 2, name: "Brinkerhoff Books")
        vm.state = s1

        // Baseline: boarded with Explorer cohort (×1.0) and base 0.5 = +0.5.
        vm.recordThoughtFired(artifactId: boardedId, cohort: .explorers)
        let boardedWeight = vm.state.artifacts.first { $0.id == boardedId }!.memoryWeight
        XCTAssertEqual(boardedWeight, 0.5, accuracy: 0.001)

        // Seal it and fire again; increment should be 0.5 × 0.5 = 0.25.
        vm.state = ArtifactActions.sealStorefront(artifactId: boardedId, vm.state)
        vm.recordThoughtFired(artifactId: boardedId, cohort: .explorers)
        let sealedWeight = vm.state.artifacts.first { $0.id == boardedId }!.memoryWeight
        XCTAssertEqual(sealedWeight - boardedWeight, 0.25, accuracy: 0.001,
                       "sealed 0.5× + explorer 1.0× + base 0.5 = +0.25")
    }

    func testDisplayAccrual() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        let (s1, aid) = closeTenant(in: vm.state, at: 2, name: "Ricky's Records")
        vm.state = ArtifactActions.repurposeAsDisplay(artifactId: aid,
                                                      content: .historicalPlaque, s1)

        let before = vm.state.artifacts.first { $0.id == aid }!.memoryWeight
        vm.recordThoughtFired(artifactId: aid, cohort: .explorers)
        let after = vm.state.artifacts.first { $0.id == aid }!.memoryWeight
        XCTAssertEqual(after - before, 0.75, accuracy: 0.001,
                       "display 1.5× × explorer 1.0× × base 0.5 = +0.75")
    }
}

// MARK: - Combined invariants

final class SealAndDisplayOfferPoolInvariantTests: XCTestCase {

    // User-specified invariant: both verbs must lock the slot from the offer pool.
    // Explicit test so this can never break silently.
    func testBothVerbsRemoveSlotFromOfferPool() {
        // Seal path.
        let (sealState, sealId) = closeTenant(in: StartingMall.initialState(),
                                               at: 2, name: "A")
        let sealed = ArtifactActions.sealStorefront(artifactId: sealId, sealState)
        let sealPicked = StoreActions.prospectiveSlotIndex(for: standardOffer, in: sealed)
        if let i = sealPicked {
            XCTAssertNotEqual(sealed.stores[i].id, 2,
                              "seal invariant: slot 2 must not be returned")
        }

        // Display path.
        let (dispState, dispId) = closeTenant(in: StartingMall.initialState(),
                                               at: 2, name: "B")
        let displayed = ArtifactActions.repurposeAsDisplay(artifactId: dispId,
                                                            content: .communityArt, dispState)
        let dispPicked = StoreActions.prospectiveSlotIndex(for: standardOffer, in: displayed)
        if let i = dispPicked {
            XCTAssertNotEqual(displayed.stores[i].id, 2,
                              "display invariant: slot 2 must not be returned")
        }
    }
}
