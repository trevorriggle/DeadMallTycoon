import Foundation

// v8: weightedPersonality() + pickMemory().
// Uses the ordered (name, weight) tuple list from Personalities.weights
// so picks are deterministic under a seeded RNG.
enum PersonalityPicker {

    // v8: weightedPersonality() + v9 Ghost Mall gate.
    // At year 5+ when the mall is struggling/dying/dead, switches to the ghost weights
    // table (which adds Paranormal Investigator, Urbex Pilgrim, Fashion Photographer).
    static func weightedPick(state: MallState, year: Int,
                             rng: inout some RandomNumberGenerator) -> String {
        let useGhost = Personalities.useGhostWeights(year: year, state: state)
        let table = useGhost
            ? (Personalities.weightsGhost[state] ?? Personalities.weights[state] ?? [])
            : (Personalities.weights[state] ?? [])
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
