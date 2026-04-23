import XCTest
@testable import DeadMallTycoon

// v9 Prompt 11 coverage — the pieces that make the endgame feel populated
// by memory:
//   - cohortAccessiblePool: older cohorts see more of each pool; slices
//     are nested (Explorers ⊆ Nostalgics ⊆ Originals).
//   - pickArtifactThought: among nearby artifacts, picks are weighted by
//     memoryWeight + floor; the bias is observable statistically over
//     many samples.
//
// Both are exposed as static helpers on PersonalityPicker so they can be
// exercised without the visitor / state plumbing.

// MARK: - cohortAccessiblePool

final class CohortPoolAccessTests: XCTestCase {

    // With a 10-string pool, fractions 0.3/0.6/1.0 → 3/6/10 strings
    // visible to Explorers/Nostalgics/Originals respectively.
    private let tenPool = (1...10).map { "t\($0)" }

    func testOriginalsSeeWholePool() {
        XCTAssertEqual(
            PersonalityPicker.cohortAccessiblePool(tenPool, cohort: .originals),
            tenPool)
    }

    func testNostalgicsSeeSixtyPercent() {
        let subset = PersonalityPicker.cohortAccessiblePool(tenPool, cohort: .nostalgics)
        XCTAssertEqual(subset.count, 6)
        XCTAssertEqual(subset, Array(tenPool.prefix(6)),
                       "first 60% — the prefix, so slices are nested")
    }

    func testExplorersSeeThirtyPercent() {
        let subset = PersonalityPicker.cohortAccessiblePool(tenPool, cohort: .explorers)
        XCTAssertEqual(subset.count, 3)
        XCTAssertEqual(subset, Array(tenPool.prefix(3)))
    }

    func testSubsetsAreNested() {
        let expl = PersonalityPicker.cohortAccessiblePool(tenPool, cohort: .explorers)
        let nost = PersonalityPicker.cohortAccessiblePool(tenPool, cohort: .nostalgics)
        let orig = PersonalityPicker.cohortAccessiblePool(tenPool, cohort: .originals)
        XCTAssertTrue(nost.starts(with: expl),
                      "Nostalgics' pool contains Explorers' pool as a prefix")
        XCTAssertTrue(orig.starts(with: nost),
                      "Originals' pool contains Nostalgics' pool as a prefix")
    }

    func testEmptyPoolStaysEmpty() {
        XCTAssertEqual(
            PersonalityPicker.cohortAccessiblePool([], cohort: .explorers), [])
        XCTAssertEqual(
            PersonalityPicker.cohortAccessiblePool([], cohort: .originals), [])
    }

    // A tiny 3-string pool should give Explorers at least 1 string
    // (round(3 * 0.3) = round(0.9) = 1), not 0.
    func testSmallPoolClampedToAtLeastOne() {
        let pool = ["a", "b", "c"]
        let expl = PersonalityPicker.cohortAccessiblePool(pool, cohort: .explorers)
        XCTAssertEqual(expl, ["a"], "3 * 0.3 rounds to 1, clamped min 1")
        let nost = PersonalityPicker.cohortAccessiblePool(pool, cohort: .nostalgics)
        XCTAssertEqual(nost, ["a", "b"], "3 * 0.6 = 1.8 → rounds to 2")
        let orig = PersonalityPicker.cohortAccessiblePool(pool, cohort: .originals)
        XCTAssertEqual(orig, pool, "3 * 1.0 = 3")
    }

    func testSingleStringPoolAllCohortsGetIt() {
        let pool = ["only"]
        for cohort in AgeCohort.allCases {
            XCTAssertEqual(
                PersonalityPicker.cohortAccessiblePool(pool, cohort: cohort),
                pool,
                "single-string pool is visible to \(cohort.rawValue)")
        }
    }
}

// MARK: - pickArtifactThought weighted bias

final class ArtifactMemoryWeightedPickTests: XCTestCase {

    // Construct two side-by-side artifacts with different memoryWeights
    // and verify pick distribution over many samples reflects the bias.
    // Pool + cohort set to trivial so the result.artifactId is the only
    // variable of interest.

    private func artifact(id: Int, memoryWeight: Double) -> Artifact {
        var a = ArtifactFactory.make(
            id: id, type: .kugelBall,
            name: "test-\(id)",
            origin: .playerAction("test"),
            yearCreated: 1985,
            thoughtTriggers: ["line"],
            x: 0, y: 0
        )
        a.memoryWeight = memoryWeight
        return a
    }

    func testEqualMemoryRoughlyUniform() {
        let a = artifact(id: 1, memoryWeight: 0)
        let b = artifact(id: 2, memoryWeight: 0)
        var counts = [1: 0, 2: 0]
        for seed in UInt64(1)...500 {
            var rng = SeededGenerator(seed: seed)
            let t = PersonalityPicker.pickArtifactThought(
                from: [a, b], cohort: .originals, rng: &rng)
            if let id = t?.artifactId { counts[id, default: 0] += 1 }
        }
        // 500 samples; 50/50 expected. Allow wide tolerance for RNG
        // variance but detect any gross bias.
        XCTAssertGreaterThan(counts[1]!, 150)
        XCTAssertGreaterThan(counts[2]!, 150)
    }

    func testHighMemoryArtifactWinsMoreOften() {
        // weights: (1 + 0) = 1 vs (1 + 99) = 100 → expect ~99% toward b.
        let a = artifact(id: 1, memoryWeight: 0)
        let b = artifact(id: 2, memoryWeight: 99)
        var counts = [1: 0, 2: 0]
        for seed in UInt64(1)...500 {
            var rng = SeededGenerator(seed: seed)
            let t = PersonalityPicker.pickArtifactThought(
                from: [a, b], cohort: .originals, rng: &rng)
            if let id = t?.artifactId { counts[id, default: 0] += 1 }
        }
        XCTAssertGreaterThan(counts[2]!, counts[1]! * 10,
                             "b has 100× the weight of a; should dominate picks")
    }

    func testFreshArtifactStillReachableOverFloor() {
        // With memoryWeightFloor = 1.0, an artifact at memoryWeight=0
        // still has a 1.0 weight baseline — it's reachable, just less
        // likely than a high-memory peer. Verify it's picked at least
        // sometimes so a fresh artifact isn't starved.
        let a = artifact(id: 1, memoryWeight: 0)
        let b = artifact(id: 2, memoryWeight: 10)   // ratio 1:11
        var picksA = 0
        for seed in UInt64(1)...500 {
            var rng = SeededGenerator(seed: seed)
            let t = PersonalityPicker.pickArtifactThought(
                from: [a, b], cohort: .originals, rng: &rng)
            if t?.artifactId == 1 { picksA += 1 }
        }
        XCTAssertGreaterThan(picksA, 10,
                             "memoryWeightFloor keeps fresh artifacts reachable (not starved)")
    }

    func testEmptyNearbyReturnsNil() {
        var rng = SeededGenerator(seed: 1)
        XCTAssertNil(PersonalityPicker.pickArtifactThought(
            from: [], cohort: .originals, rng: &rng))
    }

    func testCohortGateOnArtifactPool() {
        // Pool has 10 strings; Explorers see only the first 3. Over many
        // samples, only those 3 strings should appear in results.
        var a = ArtifactFactory.make(
            id: 1, type: .fountain, name: "f",
            origin: .playerAction("test"), yearCreated: 1985,
            thoughtTriggers: (1...10).map { "t\($0)" },
            x: 0, y: 0
        )
        a.memoryWeight = 0
        let accessibleToExplorers: Set<String> = ["t1", "t2", "t3"]
        var seenTexts = Set<String>()
        for seed in UInt64(1)...200 {
            var rng = SeededGenerator(seed: seed)
            if let t = PersonalityPicker.pickArtifactThought(
                from: [a], cohort: .explorers, rng: &rng) {
                seenTexts.insert(t.text)
            }
        }
        XCTAssertFalse(seenTexts.isEmpty, "should pick SOMETHING over 200 tries")
        XCTAssertTrue(seenTexts.isSubset(of: accessibleToExplorers),
                      "Explorers should only surface strings from the first 30% of the pool")
    }
}
