import Foundation

// v8: monthlyScore(), getLifeMultiplier(), and the year-multiplier curve.
// The year-multiplier function is isolated so Phase 5 can swap in the v9 progressive curve
// without touching monthlyScore.
enum Scoring {

    // v8: monthlyScore()
    static func monthlyScore(_ state: GameState) -> Int {
        let openStores = Mall.openStores(state)
        let vacantOpen = openStores.filter { $0.tier == .vacant }.count
        let activeTenants = openStores.filter { $0.tier != .vacant }.count
        let sealedBonus =
            (Mall.isWingClosed(.north, in: state) ? 5 : 0) +
            (Mall.isWingClosed(.south, in: state) ? 5 : 0)
        let totalEmptiness = vacantOpen + sealedBonus

        if totalEmptiness == 0 { return 0 }
        if activeTenants < 2   { return 0 }
        if state.currentTraffic < 30 { return 0 }

        let lifeMultiplier = min(1.0, Double(state.currentTraffic) / 100.0)
        let yr = Double(state.year - GameConstants.startingYear) + Double(state.month) / 12.0
        let yearMult = yearMultiplier(yearsElapsed: yr)
        let aesthetic = Economy.aestheticMult(state)
        let raw = Double(totalEmptiness) * yearMult * aesthetic * 2 * lifeMultiplier
        return Int(raw)
    }

    // v8: getLifeMultiplier()
    static func lifeMultiplier(_ state: GameState) -> Double {
        let activeTenants = Mall.openStores(state).filter { $0.tier != .vacant }.count
        if activeTenants < 2 { return 0 }
        if state.currentTraffic < 30 { return 0 }
        return min(1.0, Double(state.currentTraffic) / 100.0)
    }

    // v8 curve. Phase 5 replaces with the progressive curve that targets ~1× at y1,
    // 3× at y5, 8× at y10, 15× at y15, 25× at y20, uncapped.
    static func yearMultiplier(yearsElapsed yr: Double) -> Double {
        1.0 + min(yr * 0.12, 3.0)
    }
}
