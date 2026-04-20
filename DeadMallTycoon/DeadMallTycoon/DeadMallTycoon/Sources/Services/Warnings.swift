import Foundation

// v8: refreshWarnings() + addWarning() + the aging/culling tail.
enum Warnings {

    static func refresh(_ state: GameState) -> GameState {
        var s = state
        var seen = Set<String>()

        // Decoration decay / hazard warnings
        for d in s.decorations {
            let typeName = DecorationTypes.type(d.kind).name
            if d.condition == 3 && !d.hazard {
                let k = "decay_\(d.id)"
                seen.insert(k)
                s = add(s, key: k,
                        text: "\(typeName) is deteriorating. May become a hazard soon.",
                        severity: .watch)
            }
            if d.hazard {
                let k = "hazard_\(d.id)"
                seen.insert(k)
                s = add(s, key: k,
                        text: "\(typeName) is a hazard. Monthly fine active.",
                        severity: .warn)
            }
        }

        // Low traffic bands
        if s.consecutiveLowTrafficMonths >= 2 {
            let k = "low_traffic_2"
            seen.insert(k)
            s = add(s, key: k,
                    text: "Foot traffic has been weak for \(s.consecutiveLowTrafficMonths) months. City scrutiny rising.",
                    severity: .warn)
        }
        if s.consecutiveLowTrafficMonths >= 4 {
            let k = "low_traffic_4"
            seen.insert(k)
            s = add(s, key: k,
                    text: "Prolonged low traffic will trigger an inspection soon.",
                    severity: .danger)
        }

        // Sealed-wing crime warning
        if Mall.closedWingsCount(s) > 0 && !s.activeStaff.security {
            let k = "wing_crime"
            seen.insert(k)
            s = add(s, key: k,
                    text: "Sealed wings are attracting trespassers. Hire Security or risk vandalism.",
                    severity: .warn)
        }

        // Offer drought (one-shot: sticks without refreshing once seen)
        let mallState = Mall.state(s)
        if (mallState == .dying || mallState == .dead)
            && !s.warnings.contains(where: { $0.key == "offer_drought" }) {
            let k = "offer_drought"
            seen.insert(k)
            s = add(s, key: k,
                    text: "Vacancy is discouraging new tenant interest. Offers will be rare.",
                    severity: .watch)
        }

        // Per-store warnings
        for store in s.stores {
            if store.tier == .vacant || Mall.isWingClosed(store.wing, in: s) { continue }
            if store.hardship >= 2 && !store.closing {
                let k = "struggle_\(store.id)"
                seen.insert(k)
                s = add(s, key: k,
                        text: "\(store.name) is struggling to make rent. Traffic below their viability threshold.",
                        severity: .watch)
            }
            if store.lease <= 3 && store.lease > 0 && s.currentTraffic < store.threshold * 3 {
                let k = "lease_end_\(store.id)"
                seen.insert(k)
                s = add(s, key: k,
                        text: "\(store.name)'s lease ends in \(store.lease) months. Low traffic suggests they may not renew.",
                        severity: .warn)
            }
        }

        // Threat-critical (one-shot: sticks)
        if s.threatMeter >= 0.7 && !s.warnings.contains(where: { $0.key == "threat_critical" }) {
            let k = "threat_critical"
            seen.insert(k)
            s = add(s, key: k,
                    text: "Instability is critical. A disaster is likely this month or next.",
                    severity: .danger)
        }

        // Age + cull — matches v8's tail:
        //   age++; if age<=2 keep; if !seen && age>4 drop; else keep while age<10.
        s.warnings = s.warnings.compactMap { w in
            var w = w
            w.age += 1
            if w.age <= 2 { return w }
            if !seen.contains(w.key) && w.age > 4 { return nil }
            return w.age < 10 ? w : nil
        }

        return s
    }

    // v8: addWarning() — dedupe by key (first writer wins)
    private static func add(_ state: GameState, key: String, text: String, severity: Severity) -> GameState {
        var s = state
        if s.warnings.contains(where: { $0.key == key }) { return s }
        s.warnings.append(Warning(key: key, text: text, severity: severity, age: 0))
        return s
    }

    // v8: warnings-panel sorts by severity (danger first) and slices first 6
    static func sorted(_ state: GameState) -> [Warning] {
        state.warnings.sorted { $0.severity.sortOrder < $1.severity.sortOrder }
    }
}
