import Foundation

// v9 Prompt 14 — the second failure mode. A run ends not only at the debt
// ceiling but also when the mall forgets itself. Three conditions must be
// simultaneously true:
//
//   1. Total memoryWeight across all artifacts is below memoryFailureThreshold
//      (instantaneous check — a careful run with a few weighted artifacts
//       stays above this floor indefinitely)
//   2. Traffic has been below trafficFloor for at least trafficFloorMonths
//      consecutive months (sustained low visitorship)
//   3. Mall state has been .dead or .ghostMall for at least deadOrGhostMonths
//      consecutive months (sustained collapse — short dips don't qualify)
//
// The durations are deliberately long (12 and 24 months) so a temporary
// bad patch doesn't accidentally end the run. Forgotten is a slow failure:
// the mall has to actually be forgotten, not just quiet for a season.
enum FailureTuning {
    // Total memoryWeight across all artifacts. Above this value the mall
    // is "remembered enough" for the failure mode to stay dormant. A
    // handful of weighted artifacts (few dozen weight total) clears this
    // floor comfortably. (Prompt 14)
    static let memoryFailureThreshold: Double = 15.0

    // Absolute traffic count (state.currentTraffic). Below this value
    // counts as "below floor." Dead state's target visitor count is ~4,
    // so this condition trips reliably once a mall collapses;
    // thriving's ~22+ keeps it dormant. (Prompt 14)
    static let trafficFloor: Int = 15

    // Consecutive months required below trafficFloor before the
    // sustained-low-traffic gate is open. One full in-game year.
    // (Prompt 14)
    static let trafficFloorMonths: Int = 12

    // Consecutive months required in .dead (includes .ghostMall via
    // monthsInDeadState which counts both) before the sustained-
    // collapse gate is open. Two in-game years. (Prompt 14)
    static let deadOrGhostMonths: Int = 24
}

enum FailureMode {
    // Pure check. Returns true iff all three memorial-failure
    // conditions are satisfied simultaneously. Called each tick from
    // TickEngine after the debt-ceiling check (bankruptcy takes
    // precedence — a mall going broke IS a failure, no need to also
    // check for memorial neglect).
    static func shouldForget(_ state: GameState) -> Bool {
        guard state.totalMemoryWeight < FailureTuning.memoryFailureThreshold else {
            return false
        }
        guard state.consecutiveMonthsBelowTrafficFloor
                >= FailureTuning.trafficFloorMonths else {
            return false
        }
        guard state.monthsInDeadState >= FailureTuning.deadOrGhostMonths else {
            return false
        }
        return true
    }
}
