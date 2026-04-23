import XCTest
@testable import DeadMallTycoon

// v9 Prompt 14 coverage. Two failure modes coexist:
//   .bankruptcy — existing debt-ceiling trigger, now stamps gameOverReason
//   .forgotten  — new three-condition trigger (memory < threshold AND
//                 consecutiveMonthsBelowTrafficFloor >= 12 AND
//                 monthsInDeadState >= 24)
// Bankruptcy takes precedence when both trigger in the same tick —
// economic collapse dominates memorial neglect.

// MARK: - FailureMode.shouldForget (pure check)

final class ShouldForgetPureCheckTests: XCTestCase {

    // Helper: construct a state with all three conditions satisfied.
    private func forgottenState() -> GameState {
        var s = StartingMall.initialState()
        // Thin memory: zero out every artifact's weight, total stays well
        // under the 15.0 threshold.
        for i in s.artifacts.indices { s.artifacts[i].memoryWeight = 0 }
        // Sustained traffic-below-floor counter at the threshold.
        s.consecutiveMonthsBelowTrafficFloor = FailureTuning.trafficFloorMonths
        // Sustained dead-state counter at the threshold.
        s.monthsInDeadState = FailureTuning.deadOrGhostMonths
        return s
    }

    func testAllThreeConditionsSatisfiedReturnsTrue() {
        let s = forgottenState()
        XCTAssertTrue(FailureMode.shouldForget(s))
    }

    func testMemoryAboveThresholdDoesNotTrigger() {
        var s = forgottenState()
        s.artifacts[0].memoryWeight = FailureTuning.memoryFailureThreshold + 1
        XCTAssertFalse(FailureMode.shouldForget(s),
                       "memory above threshold keeps the mall 'remembered'")
    }

    func testTrafficFloorCounterShortOfThresholdDoesNotTrigger() {
        var s = forgottenState()
        s.consecutiveMonthsBelowTrafficFloor = FailureTuning.trafficFloorMonths - 1
        XCTAssertFalse(FailureMode.shouldForget(s),
                       "one month short of traffic-floor duration doesn't fire")
    }

    func testDeadStateDurationShortOfThresholdDoesNotTrigger() {
        var s = forgottenState()
        s.monthsInDeadState = FailureTuning.deadOrGhostMonths - 1
        XCTAssertFalse(FailureMode.shouldForget(s))
    }

    func testBoundaryExactlyAtThresholdsFires() {
        var s = forgottenState()
        // Memory at exactly threshold doesn't qualify (strict `<`)
        s.artifacts[0].memoryWeight = FailureTuning.memoryFailureThreshold
        XCTAssertFalse(FailureMode.shouldForget(s),
                       "memory EQUAL to threshold does not trigger (strict <)")
        // Just below: fires.
        s.artifacts[0].memoryWeight = FailureTuning.memoryFailureThreshold - 0.01
        XCTAssertTrue(FailureMode.shouldForget(s))
    }
}

// MARK: - Tick counter behavior

final class TrafficFloorCounterTests: XCTestCase {

    func testCounterIncrementsWhenTrafficBelowFloor() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        // Force traffic below floor by nuking the mall's occupancy.
        for i in s.stores.indices { s.stores[i].tier = .vacant }
        XCTAssertEqual(s.consecutiveMonthsBelowTrafficFloor, 0)

        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertEqual(s.consecutiveMonthsBelowTrafficFloor, 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertEqual(s.consecutiveMonthsBelowTrafficFloor, 2)
    }

    func testCounterResetsCleanlyOnFloorMet() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s.consecutiveMonthsBelowTrafficFloor = 10
        // Ensure traffic stays healthy: starting mall is thriving.
        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertEqual(s.consecutiveMonthsBelowTrafficFloor, 0,
                       "counter resets to 0 on any tick that meets the floor — " +
                       "not slow-decrement like consecutiveLowTrafficMonths")
    }
}

// MARK: - TickEngine gameover reason stamping

final class GameOverReasonStampingTests: XCTestCase {

    func testBankruptcyStampsReason() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        // Force bankruptcy: debt just past the ceiling.
        s.debt = GameConstants.debtCeiling
        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertTrue(s.gameover)
        XCTAssertEqual(s.gameOverReason, .bankruptcy)
    }

    func testForgottenStampsReason() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        // Pre-load all three conditions so the tick-end memory-failure
        // check fires.
        for i in s.artifacts.indices { s.artifacts[i].memoryWeight = 0 }
        s.consecutiveMonthsBelowTrafficFloor = FailureTuning.trafficFloorMonths
        s.monthsInDeadState = FailureTuning.deadOrGhostMonths

        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertTrue(s.gameover)
        XCTAssertEqual(s.gameOverReason, .forgotten)
    }

    func testBankruptcyPrecedenceWhenBothConditionsTriggerSameTick() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s.debt = GameConstants.debtCeiling
        // Also pre-load the memory-failure conditions.
        for i in s.artifacts.indices { s.artifacts[i].memoryWeight = 0 }
        s.consecutiveMonthsBelowTrafficFloor = FailureTuning.trafficFloorMonths
        s.monthsInDeadState = FailureTuning.deadOrGhostMonths

        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertTrue(s.gameover)
        XCTAssertEqual(s.gameOverReason, .bankruptcy,
                       "bankruptcy check is first; economic collapse dominates memorial neglect")
    }
}

// MARK: - Aggressive vs neglectful narrative

final class FailureModeNarrativeTests: XCTestCase {

    // A vacancy-maximizing run tends toward bankruptcy: many vacant slots
    // accumulate the $350/mo penalty, low rent, debt spirals. Memory
    // substrate can still be healthy from thoughts fired on memorial
    // artifacts. The bankruptcy trigger fires first.
    func testVacancyMaxRunWithHealthyMemoryHitsBankruptcyNotForgotten() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        // Healthy memory — above threshold.
        for i in s.artifacts.indices { s.artifacts[i].memoryWeight = 4.0 }
        XCTAssertGreaterThan(s.totalMemoryWeight,
                              FailureTuning.memoryFailureThreshold)
        // Sustained below-traffic-floor, sustained dead state.
        s.consecutiveMonthsBelowTrafficFloor = FailureTuning.trafficFloorMonths
        s.monthsInDeadState = FailureTuning.deadOrGhostMonths
        XCTAssertFalse(FailureMode.shouldForget(s),
                       "healthy memory keeps the forgotten gate closed " +
                       "— this run would bankrupt instead")

        // Bankruptcy still fires when debt ceiling is breached.
        s.debt = GameConstants.debtCeiling
        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertEqual(s.gameOverReason, .bankruptcy)
    }

    // A neglectful run with full occupancy and no curation: memory
    // substrate never accumulates (no memorials spawned, artifacts
    // rarely visited in proximity), traffic eventually tanks, the
    // mall drifts into the forgotten failure mode.
    func testNeglectfulRunHitsForgotten() {
        // Build the state directly — simulating 24 years of play in a
        // test would be a nightmare.
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        // Thin memory across the whole mall.
        for i in s.artifacts.indices { s.artifacts[i].memoryWeight = 0 }
        // Sustained low traffic, sustained dead state, memory thin.
        s.consecutiveMonthsBelowTrafficFloor = FailureTuning.trafficFloorMonths
        s.monthsInDeadState = FailureTuning.deadOrGhostMonths
        // No debt (didn't go broke — just forgotten).
        s.debt = 0

        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertTrue(s.gameover)
        XCTAssertEqual(s.gameOverReason, .forgotten)
    }
}
