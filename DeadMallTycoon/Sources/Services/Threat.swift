import Foundation

// v8: calculateThreat(), getThreatBand(), getThreatReason().
enum Threat {

    // v8: calculateThreat()
    static func calculate(_ state: GameState) -> Double {
        let hazards = state.decorations.filter { $0.hazard }.count
        let closedWingsCount = Mall.closedWingsCount(state)
        let openStores = Mall.openStores(state)
        let occ = openStores.filter { $0.tier != .vacant }.count
        let total = max(1, openStores.count)
        let vacancyRatio = 1.0 - Double(occ) / Double(total)
        let lowTrafficFactor = Double(state.consecutiveLowTrafficMonths) * 0.03
        let maintenanceReduction = state.activeStaff.maintenance ? 0.5 : 1.0
        let securityReduction    = state.activeStaff.security    ? 0.7 : 1.0
        let base = 0.02
        let threat = (base
                      + Double(hazards) * 0.04
                      + Double(closedWingsCount) * 0.06
                      + vacancyRatio * 0.08
                      + lowTrafficFactor)
                     * maintenanceReduction * securityReduction
        return min(1.0, threat * 6)
    }

    // v8: getThreatBand()
    static func band(_ t: Double) -> ThreatBand {
        if t < 0.25 { return .stable }
        if t < 0.50 { return .uneasy }
        if t < 0.75 { return .risky  }
        return .critical
    }

    // v8: getThreatReason()
    static func reason(_ state: GameState) -> String {
        var parts: [String] = []
        let h = state.decorations.filter { $0.hazard }.count
        let cw = Mall.closedWingsCount(state)
        if h  > 0 { parts.append("\(h) hazard\(h > 1 ? "s" : "")") }
        if cw > 0 { parts.append("\(cw) sealed wing\(cw > 1 ? "s" : "")") }
        if state.consecutiveLowTrafficMonths >= 2 {
            parts.append("weak traffic \(state.consecutiveLowTrafficMonths)mo")
        }
        let openStores = Mall.openStores(state)
        let vac = openStores.filter { $0.tier == .vacant }.count
        let total = max(1, openStores.count)
        if Double(vac) / Double(total) > 0.4 { parts.append("high vacancy") }
        return parts.isEmpty ? "Steady" : parts.joined(separator: " · ")
    }
}
