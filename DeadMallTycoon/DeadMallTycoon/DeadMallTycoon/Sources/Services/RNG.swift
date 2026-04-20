import Foundation

// SplitMix64 seeded RNG. Used by TickEngine and EventDeck so tests are reproducible
// (v8 uses Math.random directly; the Swift port injects the generator as inout so tests
// can pin behavior to a known seed).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// Small convenience surface so call sites read like v8 (Math.random() < p etc.)
extension RandomNumberGenerator {
    mutating func chance(_ p: Double) -> Bool {
        Double.random(in: 0..<1, using: &self) < p
    }

    mutating func double(in range: Range<Double>) -> Double {
        Double.random(in: range, using: &self)
    }

    mutating func int(in range: Range<Int>) -> Int {
        Int.random(in: range, using: &self)
    }

    mutating func pick<T>(_ array: [T]) -> T? {
        guard !array.isEmpty else { return nil }
        let i = Int.random(in: 0..<array.count, using: &self)
        return array[i]
    }
}
