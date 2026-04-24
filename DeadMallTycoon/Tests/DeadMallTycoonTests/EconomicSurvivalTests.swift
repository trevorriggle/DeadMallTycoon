import XCTest
@testable import DeadMallTycoon

// v9 Prompt 21 — economic survival fixes. Coverage for the five fixes
// in the single commit. Test target isn't wired to the Xcode project
// yet (per CLAUDE.md), so these are static documentation tests — the
// assertions describe the contract, not a CI gate.

// MARK: - Fix 1 · Anchor sealing eligibility

final class AnchorSealingEligibilityTests: XCTestCase {

    func testWingWithActiveAnchorIsNotEligible() {
        let s = StartingMall.initialState()
        // Both starting wings seed an anchor (Halvorsen north, Pemberton south)
        // so neither wing should appear in eligibleWings.
        let eligible = Sealing.eligibleWings(in: s)
        XCTAssertTrue(eligible.isEmpty,
                      "wings with active anchors are not sealable")
    }

    func testWingBecomesEligibleAfterAnchorDeparts() {
        var s = StartingMall.initialState()
        // Vacate the first anchor (index 0 in the storeSeeds = Halvorsen, north).
        let northAnchorIdx = s.stores.firstIndex {
            $0.wing == .north && $0.tier == .anchor
        }!
        s = TenantLifecycle.vacateSlot(storeIndex: northAnchorIdx, state: s)

        let eligible = Sealing.eligibleWings(in: s)
        XCTAssertTrue(eligible.contains(.north),
                      "north wing is sealable after its anchor departs")
        XCTAssertFalse(eligible.contains(.south),
                       "south wing still has its anchor and is not sealable")
    }

    func testWingHasActiveAnchorHelper() {
        let s = StartingMall.initialState()
        XCTAssertTrue(Sealing.wingHasActiveAnchor(.north, in: s))
        XCTAssertTrue(Sealing.wingHasActiveAnchor(.south, in: s))
    }

    func testActiveTenantCountExcludesAnchor() {
        let s = StartingMall.initialState()
        // Starting seed: north wing has 1 anchor + 8 standards + 0 kiosks.
        // Sealing.activeTenantCount excludes anchors, so the north-wing
        // count should equal the non-anchor non-vacant stores.
        let count = Sealing.activeTenantCount(in: .north, s)
        let expected = s.stores.filter {
            $0.wing == .north && $0.tier != .anchor && $0.tier != .vacant
        }.count
        XCTAssertEqual(count, expected,
                       "activeTenantCount excludes anchors post-Prompt-21")
        // Sanity: at least one non-anchor tenant exists on the north wing.
        XCTAssertGreaterThan(count, 0)
    }

    func testConfirmSealWingRefusesAnchoredWing() {
        let vm = GameViewModel(seed: 1)
        vm.startGame(tutorialEnabled: false)
        XCTAssertTrue(Sealing.wingHasActiveAnchor(.north, in: vm.state),
                      "precondition: north wing has active anchor")
        XCTAssertFalse(vm.state.wingsClosed[.north] ?? false)

        // Force the SealAction through confirmSeal; the defense-in-depth
        // guard inside confirmSeal should refuse the mutation.
        vm.state.pendingSealAction = .wing(.north)
        vm.confirmSeal()

        XCTAssertFalse(vm.state.wingsClosed[.north] ?? false,
                       "wing-seal on an anchored wing is a no-op")
        XCTAssertNil(vm.state.pendingSealAction,
                     "pendingSealAction always clears even when guarded off")
    }
}

// MARK: - Fix 2 · Hazard tuning

final class HazardTuningTests: XCTestCase {

    func testTuningConstantsHalved() {
        // Lock in the Prompt 21 values so future drift is intentional.
        XCTAssertEqual(ArtifactTuning.decayBaseProbability, 0.01,
                       accuracy: 0.0001,
                       "base decay halved from 0.02")
        XCTAssertEqual(ArtifactTuning.decayConditionStep, 0.005,
                       accuracy: 0.0001,
                       "per-condition step halved from 0.01")
        XCTAssertEqual(ArtifactTuning.hazardOnDecayToRuinChance, 0.20,
                       accuracy: 0.0001,
                       "hazard-on-decay-to-4 halved from 0.40")
        XCTAssertEqual(ArtifactTuning.hazardAtRuinChance, 0.075,
                       accuracy: 0.0001,
                       "hazard-at-4 halved from 0.15")
        XCTAssertEqual(ArtifactTuning.maxHazardFinesPerTick, 1)
    }

    func testHazardFinesCappedToOnePerTick() {
        var s = StartingMall.initialState()
        // Flag three artifacts as hazard at different conditions.
        s.artifacts[0].hazard = true; s.artifacts[0].condition = 2
        s.artifacts[1].hazard = true; s.artifacts[1].condition = 4
        s.artifacts[2].hazard = true; s.artifacts[2].condition = 3

        let items = Economy.hazardFinesByArtifact(s)
        XCTAssertEqual(items.count, ArtifactTuning.maxHazardFinesPerTick,
                       "only one hazard fine bills per tick")
        // The single fine picked must be the largest (condition 4 = $1300).
        XCTAssertEqual(items[0].artifactId, s.artifacts[1].id)
        XCTAssertEqual(items[0].amount, 500 + 4 * 200)
    }

    func testHazardFinesTiebreakerIsLowestId() {
        var s = StartingMall.initialState()
        // Two hazards at the same condition → tie on amount. Lower id wins.
        s.artifacts[1].hazard = true; s.artifacts[1].condition = 4
        s.artifacts[3].hazard = true; s.artifacts[3].condition = 4

        let items = Economy.hazardFinesByArtifact(s)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].artifactId, s.artifacts[1].id,
                       "tie-break: lower artifactId bills first")
    }

    func testSingleHazardPassesThroughUnchanged() {
        var s = StartingMall.initialState()
        s.artifacts[0].hazard = true
        s.artifacts[0].condition = 3
        let items = Economy.hazardFinesByArtifact(s)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].amount, 500 + 3 * 200)
    }

    func testHazardFinesAggregateMatchesCappedItems() {
        // Economy.hazardFines sums hazardFinesByArtifact; after Prompt 21's
        // cap the two values should still agree (both cap at one entry).
        var s = StartingMall.initialState()
        s.artifacts[0].hazard = true; s.artifacts[0].condition = 2
        s.artifacts[1].hazard = true; s.artifacts[1].condition = 4

        let items = Economy.hazardFinesByArtifact(s)
        XCTAssertEqual(items.reduce(0) { $0 + $1.amount },
                       Economy.hazardFines(s),
                       "aggregate fines equal the sum of the capped items")
    }
}

// MARK: - Fix 3 · Debt persistence across ticks

final class DebtPersistenceTests: XCTestCase {

    func testDebtPersistsAcrossTickBoundary() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil   // quiet the opening event
        s.debt = 5_000
        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertGreaterThanOrEqual(s.debt, 5_000,
                                    "pre-existing debt never decreases on its own")
    }

    func testNoImplicitDebtInterest() {
        // Audit gate: if someone introduces interest without a tuning
        // constant, this test catches it. A debt that sits across many
        // ticks while cash covers all costs must not grow.
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s.cash = 1_000_000                 // cover any operating costs
        s.debt = 7_500
        var rng = SeededGenerator(seed: 42)
        for _ in 0..<24 {
            s = TickEngine.tick(s, rng: &rng)
        }
        XCTAssertEqual(s.debt, 7_500,
                       "debt doesn't accrue interest (audited in Prompt 21)")
    }
}

// MARK: - Fix 4 · Bankruptcy warning card

final class BankruptcyWarningTests: XCTestCase {

    func testWarningFiresWhenDebtCrossesThreshold() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s.cash = 0
        // Seed ops-inducing state so debt grows during the tick.
        // Simpler: set debt just above the threshold pre-tick.
        s.debt = FailureTuning.bankruptcyWarningThreshold + 1

        XCTAssertFalse(s.bankruptcyWarningShown)
        XCTAssertFalse(s.bankruptcyWarningPending)

        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)

        XCTAssertTrue(s.bankruptcyWarningShown,
                      "latch sets once debt crosses threshold")
        XCTAssertTrue(s.bankruptcyWarningPending,
                      "card becomes visible on the crossing tick")
    }

    func testWarningBelowThresholdDoesNotFire() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s.debt = FailureTuning.bankruptcyWarningThreshold - 1
        s.cash = 1_000_000   // ensure the tick doesn't push debt up
        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertFalse(s.bankruptcyWarningShown)
        XCTAssertFalse(s.bankruptcyWarningPending)
    }

    func testWarningFiresExactlyOncePerRun() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s.debt = FailureTuning.bankruptcyWarningThreshold + 1
        s.cash = 1_000_000

        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertTrue(s.bankruptcyWarningPending)

        // Player acknowledges — clears Pending, keeps Shown.
        let vm = GameViewModel(seed: 1)
        vm.state = s
        vm.dismissBankruptcyWarning()
        XCTAssertFalse(vm.state.bankruptcyWarningPending)
        XCTAssertTrue(vm.state.bankruptcyWarningShown,
                      "latch stays set after Acknowledge")

        // Further ticks must not re-fire the card, even while debt is
        // still above the threshold.
        for _ in 0..<10 {
            vm.state = TickEngine.tick(vm.state, rng: &rng)
        }
        XCTAssertFalse(vm.state.bankruptcyWarningPending,
                       "the warning does not re-fire for the rest of the run")
    }

    func testWarningDoesNotReFireAfterPayDownAndReCrossing() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s.debt = FailureTuning.bankruptcyWarningThreshold + 500
        s.cash = 1_000_000

        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertTrue(s.bankruptcyWarningPending)

        // Simulate Acknowledge + pay-down + subsequent re-crossing.
        s.bankruptcyWarningPending = false
        s.debt = FailureTuning.bankruptcyWarningThreshold - 5_000   // pay-down
        s.debt = FailureTuning.bankruptcyWarningThreshold + 1       // re-cross

        s = TickEngine.tick(s, rng: &rng)

        XCTAssertFalse(s.bankruptcyWarningPending,
                       "re-crossing the threshold does not re-fire the card")
        XCTAssertTrue(s.bankruptcyWarningShown,
                      "latch stays set for the rest of the run")
    }
}

// MARK: - Fix 5 · Pay Down Debt

final class PayDownDebtTests: XCTestCase {

    private func vmWithCashAndDebt(cash: Int, debt: Int) -> GameViewModel {
        let vm = GameViewModel(seed: 1)
        vm.state.cash = cash
        vm.state.debt = debt
        return vm
    }

    func testValidPaymentReducesBothByEqualAmount() {
        let vm = vmWithCashAndDebt(cash: 10_000, debt: 8_000)
        let ok = vm.payDownDebt(amount: 3_000)
        XCTAssertTrue(ok)
        XCTAssertEqual(vm.state.cash, 7_000)
        XCTAssertEqual(vm.state.debt, 5_000)
    }

    func testMinimumPaymentAccepted() {
        let vm = vmWithCashAndDebt(cash: 500, debt: 500)
        XCTAssertTrue(vm.payDownDebt(amount: GameViewModel.payDownDebtMinimum))
        XCTAssertEqual(vm.state.cash, 500 - GameViewModel.payDownDebtMinimum)
        XCTAssertEqual(vm.state.debt, 500 - GameViewModel.payDownDebtMinimum)
    }

    func testBelowMinimumRejected() {
        let vm = vmWithCashAndDebt(cash: 10_000, debt: 10_000)
        XCTAssertFalse(vm.payDownDebt(amount: 50),
                       "amounts below the $100 floor are rejected")
        XCTAssertEqual(vm.state.cash, 10_000)
        XCTAssertEqual(vm.state.debt, 10_000)
    }

    func testNegativeRejected() {
        let vm = vmWithCashAndDebt(cash: 5_000, debt: 5_000)
        XCTAssertFalse(vm.payDownDebt(amount: -500))
        XCTAssertEqual(vm.state.cash, 5_000)
        XCTAssertEqual(vm.state.debt, 5_000)
    }

    func testExceedsCashRejected() {
        let vm = vmWithCashAndDebt(cash: 1_000, debt: 10_000)
        XCTAssertFalse(vm.payDownDebt(amount: 2_000),
                       "payment can't exceed available cash")
        XCTAssertEqual(vm.state.cash, 1_000)
        XCTAssertEqual(vm.state.debt, 10_000)
    }

    func testExceedsDebtRejected() {
        let vm = vmWithCashAndDebt(cash: 10_000, debt: 500)
        XCTAssertFalse(vm.payDownDebt(amount: 2_000),
                       "payment can't exceed current debt")
        XCTAssertEqual(vm.state.cash, 10_000)
        XCTAssertEqual(vm.state.debt, 500)
    }

    func testPayMaxWithCashLessThanDebt() {
        let vm = vmWithCashAndDebt(cash: 3_000, debt: 10_000)
        XCTAssertTrue(vm.payDownDebtMax())
        XCTAssertEqual(vm.state.cash, 0)
        XCTAssertEqual(vm.state.debt, 7_000,
                       "Pay Max with cash<debt drains cash, debt decreases by cash")
    }

    func testPayMaxWithDebtLessThanCash() {
        let vm = vmWithCashAndDebt(cash: 10_000, debt: 3_000)
        XCTAssertTrue(vm.payDownDebtMax())
        XCTAssertEqual(vm.state.cash, 7_000,
                       "Pay Max with debt<cash clears debt, cash decreases by debt")
        XCTAssertEqual(vm.state.debt, 0)
    }

    func testPayMaxBelowMinimumRejected() {
        let vm = vmWithCashAndDebt(cash: 50, debt: 10_000)
        XCTAssertFalse(vm.payDownDebtMax(),
                       "Pay Max rejects when the max is below the minimum")
        XCTAssertEqual(vm.state.cash, 50)
        XCTAssertEqual(vm.state.debt, 10_000)
    }

    func testPayMaxNoDebtRejected() {
        let vm = vmWithCashAndDebt(cash: 10_000, debt: 0)
        XCTAssertFalse(vm.payDownDebtMax())
        XCTAssertEqual(vm.state.cash, 10_000)
        XCTAssertEqual(vm.state.debt, 0)
    }
}
