import Foundation

// v8: weightedPersonality() + pickMemory().
// Uses the ordered (name, weight) tuple list from Personalities.weights
// so picks are deterministic under a seeded RNG.
enum PersonalityPicker {

    // v8: weightedPersonality()
    static func weightedPick(state: MallState, rng: inout some RandomNumberGenerator) -> String {
        let table = Personalities.weights[state] ?? []
        let total = table.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return "Casual Browser" }
        // v8: r = Math.random() * total; then r -= w for each; return when r <= 0
        var r = rng.double(in: 0..<Double(total))
        for (name, w) in table {
            r -= Double(w)
            if r <= 0 { return name }
        }
        return "Casual Browser"
    }

    // v8: pickMemory()
    static func pickMemory(for visitor: Visitor, in state: GameState,
                           rng: inout some RandomNumberGenerator) -> String {
        let mallState = Mall.state(state)
        guard let p = Personalities.all[visitor.personality],
              let pool = p.thoughts[mallState],
              !pool.isEmpty else {
            return "\"...\""
        }
        return rng.pick(pool) ?? "\"...\""
    }
}
