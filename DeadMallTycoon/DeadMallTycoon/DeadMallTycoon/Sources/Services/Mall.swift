import Foundation

// Read-only queries about the current state of the mall.
// Matches v8: getMallState(), getMoodText(), getAbandonmentLevel(), isWingClosed().
enum Mall {

    // v8: getMallState()
    static func state(_ state: GameState) -> MallState {
        let openStores = state.stores.filter { !isWingClosed($0.wing, in: state) }
        let occ = openStores.filter { $0.tier != .vacant }.count
        let total = max(1, openStores.count)
        let r = Double(occ) / Double(total)
        if r >= 0.85 { return .thriving }
        if r >= 0.65 { return .fading }
        if r >= 0.40 { return .struggling }
        if r >= 0.20 { return .dying }
        return .dead
    }

    // v8: getMoodText()
    static func moodText(_ state: GameState) -> String {
        switch Mall.state(state) {
        case .thriving:   return "The mall is alive. Fluorescent lights hum."
        case .fading:     return "Something feels different. A little quieter."
        case .struggling: return "Half the corridor is quiet."
        case .dying:      return "The mall echoes. Most stores are closed."
        case .dead:       return "You can hear your own footsteps."
        }
    }

    // v8: isWingClosed()
    static func isWingClosed(_ wing: Wing, in state: GameState) -> Bool {
        state.wingsClosed[wing] ?? false
    }

    static func isWingDowngraded(_ wing: Wing, in state: GameState) -> Bool {
        state.wingsDowngraded[wing] ?? false
    }

    // v9 Prompt 6.5 — per-corner sealing + open-count helpers.
    //
    // An entrance is "open" iff the corner isn't in sealedEntrances AND its
    // wing isn't closed. Wing closure is a broader cut (both corners on that
    // wing get hidden); sealing is per-corner. Consumers should call
    // openEntrances/openEntranceCount — never inspect sealedEntrances directly
    // so the wing-closure rule stays coherent.
    static func isEntranceSealed(_ corner: EntranceCorner, in state: GameState) -> Bool {
        state.sealedEntrances.contains(corner)
    }

    static func openEntrances(in state: GameState) -> Set<EntranceCorner> {
        var open: Set<EntranceCorner> = []
        for corner in EntranceCorner.allCases {
            if state.sealedEntrances.contains(corner) { continue }
            if isWingClosed(corner.wing, in: state) { continue }
            open.insert(corner)
        }
        return open
    }

    static func openEntranceCount(in state: GameState) -> Int {
        openEntrances(in: state).count
    }

    // v8: getAbandonmentLevel()
    static func abandonmentLevel(_ state: GameState) -> Int {
        switch Mall.state(state) {
        case .thriving:   return 0
        case .fading:     return 1
        case .struggling: return 2
        case .dying:      return 3
        case .dead:       return 4
        }
    }

    static func closedWingsCount(_ state: GameState) -> Int {
        Wing.allCases.filter { isWingClosed($0, in: state) }.count
    }

    static func openStores(_ state: GameState) -> [Store] {
        state.stores.filter { !isWingClosed($0.wing, in: state) }
    }

    static func occupancyRatio(_ state: GameState) -> Double {
        let open = openStores(state)
        let total = max(1, open.count)
        let occ = open.filter { $0.tier != .vacant }.count
        return Double(occ) / Double(total)
    }
}
