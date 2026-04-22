import XCTest
@testable import DeadMallTycoon

// v9 Prompt 6 coverage. Memorial cost surfaces on the tenant-offer banner
// when accepting would destroy a boardedStorefront memorial on the slot
// the offer would fill. Accepting removes the memorial + writes an
// .offerDestruction ledger entry; declining preserves it.

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

// Standard (non-anchor) offer used across tests — matches a non-anchor vacant slot.
private let standardOffer = TenantOffer(
    name: "GameStop", tier: .standard, rent: 750, traffic: 50,
    threshold: 25, lease: 24, pitch: "Teen traffic."
)

// MARK: - Prospective slot lookup

final class ProspectiveSlotTests: XCTestCase {

    func testProspectiveSlotFindsFirstCompatibleVacancy() {
        let s = StartingMall.initialState()
        // StartingMall seeds two vacant non-anchor slots. Either is fine.
        let idx = StoreActions.prospectiveSlotIndex(for: standardOffer, in: s)
        XCTAssertNotNil(idx, "there should be at least one compatible vacant slot")
        if let i = idx {
            XCTAssertEqual(s.stores[i].tier, .vacant)
            XCTAssertLessThan(s.stores[i].position.w, 180, "non-anchor offer → non-anchor slot")
        }
    }

    func testProspectiveSlotReturnsNilWhenNoCompatible() {
        var s = StartingMall.initialState()
        // Fill every non-anchor vacant slot so no compatible target remains.
        for i in s.stores.indices where s.stores[i].tier == .vacant {
            s.stores[i].tier = .standard
        }
        let idx = StoreActions.prospectiveSlotIndex(for: standardOffer, in: s)
        XCTAssertNil(idx)
    }
}

// MARK: - Memorial cost resolution

final class MemorialCostResolutionTests: XCTestCase {

    func testMemorialCostNilForFreshVacancy() {
        let s = StartingMall.initialState()
        // Starting vacancies have no prior tenant → no boardedStorefront.
        let cost = StoreActions.memorialCost(for: standardOffer, in: s)
        XCTAssertNil(cost, "fresh vacancy (no prior tenant) → no memorial cost")
    }

    func testMemorialCostPopulatedWhenBoardedStorefrontPresent() {
        var s = StartingMall.initialState()
        // Close a non-anchor tenant so a boardedStorefront lands on that slot.
        s = plantTenant(s, at: 2, name: "Waldenbooks", monthsOccupied: 84)
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!
        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)
        // Seed some memory weight and reference count on the memorial.
        let aidx = s.artifacts.firstIndex(where: { $0.storeSlotId == 2 })!
        s.artifacts[aidx].memoryWeight = 34.0
        s.artifacts[aidx].thoughtReferenceCount = 12
        // Advance the clock so boarded-years is meaningful.
        s.year += 7

        let cost = StoreActions.memorialCost(for: standardOffer, in: s)
        XCTAssertNotNil(cost, "slot has a boardedStorefront → memorial cost resolves")
        XCTAssertEqual(cost?.tenantName, "Waldenbooks")
        XCTAssertEqual(cost?.yearsBoarded, 7)
        XCTAssertEqual(cost?.memoryWeight, 34.0)
        XCTAssertEqual(cost?.thoughtReferenceCount, 12)
    }

    func testMemorialCostPicksMostRecentOnTiebreak() {
        // Defensive: shouldn't happen in normal play (closures only hit
        // occupied slots) but if two boardedStorefronts reference the same
        // slot, the higher id wins.
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "First")
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!
        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)
        // Manually inject a second memorial on the same slot (data anomaly).
        let newId = (s.artifacts.map(\.id).max() ?? 0) + 1
        let second = ArtifactFactory.make(
            id: newId, type: .boardedStorefront, name: "Second",
            origin: .tenant(name: "Second"), yearCreated: s.year,
            storeSlotId: 2
        )
        s.artifacts.append(second)

        let cost = StoreActions.memorialCost(for: standardOffer, in: s)
        XCTAssertEqual(cost?.tenantName, "Second",
                       "tiebreaker must pick the higher-id artifact")
    }
}

// MARK: - Accept / decline wiring

final class AcceptDestroysMemorialTests: XCTestCase {

    private func seedOffer(_ s: GameState) -> GameState {
        var s = s
        s.decision = .tenant(standardOffer)
        s.paused = true
        return s
    }

    func testAcceptRemovesBoardedStorefront() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Waldenbooks")
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!
        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)
        let beforeArtifactIds = Set(s.artifacts.map(\.id))
        let memorialId = s.artifacts.first { $0.storeSlotId == 2 }!.id

        s = seedOffer(s)
        s = StoreActions.acceptOffer(s)

        XCTAssertFalse(s.artifacts.contains { $0.id == memorialId },
                       "accepting destroys the boardedStorefront")
        XCTAssertTrue(beforeArtifactIds.subtracting(s.artifacts.map(\.id)) == [memorialId],
                      "no other artifacts should be removed")
    }

    func testAcceptAppendsOfferDestructionLedgerEntry() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Waldenbooks", monthsOccupied: 60)
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!
        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)
        let aidx = s.artifacts.firstIndex(where: { $0.storeSlotId == 2 })!
        s.artifacts[aidx].memoryWeight = 20.5
        s.artifacts[aidx].thoughtReferenceCount = 8
        s.year += 3
        let ledgerCountBefore = s.ledger.count

        s = seedOffer(s)
        s = StoreActions.acceptOffer(s)

        XCTAssertEqual(s.ledger.count, ledgerCountBefore + 1)
        guard case .offerDestruction(let oldName, let newName, let years,
                                     let weight, let thoughts, _, _) = s.ledger.last!
        else { return XCTFail("expected .offerDestruction as last entry") }
        XCTAssertEqual(oldName, "Waldenbooks")
        XCTAssertEqual(newName, standardOffer.name)
        XCTAssertEqual(years, 3)
        XCTAssertEqual(weight, 20.5)
        XCTAssertEqual(thoughts, 8)
    }

    func testAcceptOnFreshVacancyWritesNoLedgerEntry() {
        var s = StartingMall.initialState()
        s = seedOffer(s)
        let ledgerCountBefore = s.ledger.count

        s = StoreActions.acceptOffer(s)

        XCTAssertEqual(s.ledger.count, ledgerCountBefore,
                       "no memorial present → no offerDestruction entry")
    }

    func testDeclinePreservesArtifact() {
        var s = StartingMall.initialState()
        s = plantTenant(s, at: 2, name: "Waldenbooks")
        let idx = s.stores.firstIndex(where: { $0.id == 2 })!
        s = TenantLifecycle.vacateSlot(storeIndex: idx, state: s)
        let memorialId = s.artifacts.first { $0.storeSlotId == 2 }!.id
        let ledgerCountBefore = s.ledger.count

        s = seedOffer(s)
        s = StoreActions.declineOffer(s)

        XCTAssertTrue(s.artifacts.contains { $0.id == memorialId },
                      "decline must NOT destroy the memorial")
        XCTAssertEqual(s.ledger.count, ledgerCountBefore,
                       "decline must NOT write an offerDestruction entry")
    }
}
