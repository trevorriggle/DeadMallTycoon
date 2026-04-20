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

    // v9: progressive, uncapped year curve.
    // Quadratic fit through target anchors:
    //   y=0  → ~1.0×    y=1  → ~1.18×
    //   y=5  → ~3.0×
    //   y=10 → ~7.7×   (≈ 8× target)
    //   y=15 → ~15.2×
    //   y=20 → ~25.4×   (uncapped; continues rising)
    // Rewards long-term survival dramatically more than v8's cap of 4× at year 25.
    // Old v8 curve for reference: `1.0 + min(yr * 0.12, 3.0)`
    static func yearMultiplier(yearsElapsed yr: Double) -> Double {
        0.055 * yr * yr + 0.12 * yr + 1.0
    }
}
