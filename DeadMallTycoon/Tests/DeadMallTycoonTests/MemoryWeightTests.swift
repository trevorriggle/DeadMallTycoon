import XCTest
@testable import DeadMallTycoon

// v9 Prompt 4 Phase 3 coverage. Memory weight accumulation: on thought fire
// with a non-nil artifactId, the referenced artifact's memoryWeight
// increments by base (0.5) × cohort multiplier (Originals 2.5, Nostalgics
// 1.5, Explorers 1.0). Weight is monotonic in Prompt 4; scoring is not
// affected.

final class MemoryWeightTests: XCTestCase {

    func testRecordThoughtFiredIncrementsExplorer() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        guard let kugel = vm.state.artifacts.first(where: { $0.type == .kugelBall }) else {
            return XCTFail("kugel ball expected in starting seed")
        }
        let before = kugel.memoryWeight

        vm.recordThoughtFired(artifactId: kugel.id, cohort: .explorers)

        let after = vm.state.artifacts.first { $0.id == kugel.id }!.memoryWeight
        XCTAssertEqual(after - before, 0.5, accuracy: 0.001,
                       "explorer ×1.0 × base 0.5 = +0.5")
    }

    func testRecordThoughtFiredIncrementsNostalgic() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        let id = vm.state.artifacts.first!.id
        vm.recordThoughtFired(artifactId: id, cohort: .nostalgics)
        let w = vm.state.artifacts.first { $0.id == id }!.memoryWeight
        XCTAssertEqual(w, 0.75, accuracy: 0.001,
                       "nostalgic ×1.5 × base 0.5 = +0.75")
    }

    func testRecordThoughtFiredIncrementsOriginal() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        let id = vm.state.artifacts.first!.id
        vm.recordThoughtFired(artifactId: id, cohort: .originals)
        let w = vm.state.artifacts.first { $0.id == id }!.memoryWeight
        XCTAssertEqual(w, 1.25, accuracy: 0.001,
                       "original ×2.5 × base 0.5 = +1.25")
    }

    func testRepeatedThoughtsAccumulateMonotonically() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        let id = vm.state.artifacts.first!.id
        var previous = 0.0
        for _ in 0..<10 {
            vm.recordThoughtFired(artifactId: id, cohort: .nostalgics)
            let w = vm.state.artifacts.first { $0.id == id }!.memoryWeight
            XCTAssertGreaterThan(w, previous,
                                  "weight must be monotonic — no decrement paths in Prompt 4")
            previous = w
        }
        XCTAssertEqual(previous, 7.5, accuracy: 0.001,
                        "10 × 0.75 = 7.5")
    }

    func testRecordThoughtWithUnknownArtifactIdIsNoOp() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        let sumBefore = vm.state.totalMemoryWeight

        vm.recordThoughtFired(artifactId: 99_999, cohort: .originals)

        XCTAssertEqual(vm.state.totalMemoryWeight, sumBefore,
                       "unknown artifactId must not affect total memory weight")
    }

    func testPassiveThoughtPathAccruesWeightWhenTagged() {
        // Firing a passive thought at a position inside the kugel radius
        // should tag (most of the time) and add weight. Allow multiple
        // attempts to avoid flakiness from the generic-fallback roll.
        let vm = GameViewModel(seed: 3)
        vm.state = StartingMall.initialState()
        let kugel = vm.state.artifacts.first { $0.type == .kugelBall }!
        // Build a visitor positioned on the kugel.
        var rng = SeededGenerator(seed: 3)
        var v = VisitorFactory.spawn(state: vm.state, rng: &rng)
        v = Visitor(
            id: v.id,
            firstName: v.firstName, lastName: v.lastName, ageCohort: .originals,
            mood: v.mood, activity: v.activity, destinationIntent: v.destinationIntent,
            personality: v.personality, type: v.type,
            color: v.color, headColor: v.headColor, age: v.age,
            tenantIdAffinity: nil,
            x: 585, y: 245,  // on top of kugel
            vx: 0, vy: 0, speed: 0, target: nil, state: .wandering, dwellTimer: 0,
            memory: "", targetType: ""
        )
        let before = vm.state.artifacts.first { $0.id == kugel.id }!.memoryWeight
        for _ in 0..<10 {
            vm.firePassiveThought(for: v)
        }
        let after = vm.state.artifacts.first { $0.id == kugel.id }!.memoryWeight
        XCTAssertGreaterThan(after, before,
                              "10 passive thoughts on top of the kugel should add weight")
    }

    func testGenericThoughtDoesNotTouchWeight() {
        // A thought fired far from any artifact carries artifactId=nil and
        // must not touch any artifact's weight.
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        let before = vm.state.totalMemoryWeight

        var rng = SeededGenerator(seed: 1)
        var v = VisitorFactory.spawn(state: vm.state, rng: &rng)
        v = Visitor(
            id: v.id,
            firstName: v.firstName, lastName: v.lastName, ageCohort: v.ageCohort,
            mood: v.mood, activity: v.activity, destinationIntent: v.destinationIntent,
            personality: v.personality, type: v.type,
            color: v.color, headColor: v.headColor, age: v.age,
            tenantIdAffinity: nil,
            x: 10, y: 10, vx: 0, vy: 0, speed: 0,
            target: nil, state: .wandering, dwellTimer: 0,
            memory: "", targetType: ""
        )
        for _ in 0..<20 {
            vm.firePassiveThought(for: v)
        }
        XCTAssertEqual(vm.state.totalMemoryWeight, before, accuracy: 0.001,
                        "thoughts far from artifacts must not accrue weight")
    }
}

// MARK: - Regression guards

final class Prompt4RegressionTests: XCTestCase {

    // Memory weight exists but is not yet read by scoring (Prompt 5's job).
    // Pin: two states that differ only in memoryWeight produce identical
    // monthly score.
    func testScoringIgnoresMemoryWeight() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s.currentTraffic = 120
        // Force 2 slots vacant so scoring has something to count.
        for i in s.stores.indices where [10, 11].contains(s.stores[i].id) {
            s.stores[i] = Store.vacant(id: s.stores[i].id, at: s.stores[i].position)
        }
        let cleanScore = Scoring.monthlyScore(s)

        var heavyWeight = s
        for i in heavyWeight.artifacts.indices {
            heavyWeight.artifacts[i].memoryWeight = 100.0
        }
        let weightedScore = Scoring.monthlyScore(heavyWeight)

        XCTAssertEqual(cleanScore, weightedScore,
                       "Scoring.monthlyScore must ignore memoryWeight in Prompt 4")
    }

    // aestheticMult also ignores memoryWeight.
    func testAestheticMultIgnoresMemoryWeight() {
        let s = StartingMall.initialState()
        let cleanMult = Economy.aestheticMult(s)

        var heavy = s
        for i in heavy.artifacts.indices {
            heavy.artifacts[i].memoryWeight = 50
        }
        XCTAssertEqual(Economy.aestheticMult(heavy), cleanMult, accuracy: 0.01)
    }
}
