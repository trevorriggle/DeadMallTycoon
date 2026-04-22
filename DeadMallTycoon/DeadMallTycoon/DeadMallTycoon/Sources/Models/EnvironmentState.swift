import Foundation

// v9 Prompt 8 — environmental visual state machine.
//
// EnvironmentState extends the five MallState bands (thriving → dead) with a
// sixth terminal case, ghostMall, reached after 60 consecutive months in
// .dead (EnvironmentTuning.monthsInDeadForGhostMall). The counter resets on
// any recovery — a mall that drops to .dead, recovers to .dying, and falls
// back to .dead starts counting from zero again.
//
// Drives everything visual:
//   - Master brightness + saturation (SKEffectNode CIColorControls filter).
//   - Corridor-wide fluorescent flicker rate.
//   - Procedural decay overlay intensity (scales with state AND run age).
//   - Visitor isolation treatment at low corridor counts.
//   - Ambient hum volume.
//
// Note on coupling to the existing MallState: we don't rename MallState —
// it still describes the economic/occupancy band and is the honest input
// to this resolver. EnvironmentState is the consumer-facing abstraction for
// the rendering + audio layers.
enum EnvironmentState: String, Codable, CaseIterable, Equatable {
    case thriving
    case fading
    case struggling
    case dying
    case dead
    case ghostMall

    // Resolve from a GameState snapshot. Reads Mall.state + monthsInDeadState.
    static func from(_ state: GameState) -> EnvironmentState {
        let mallState = Mall.state(state)
        if mallState == .dead
            && state.monthsInDeadState >= EnvironmentTuning.monthsInDeadForGhostMall {
            return .ghostMall
        }
        switch mallState {
        case .thriving:   return .thriving
        case .fading:     return .fading
        case .struggling: return .struggling
        case .dying:      return .dying
        case .dead:       return .dead
        }
    }
}
