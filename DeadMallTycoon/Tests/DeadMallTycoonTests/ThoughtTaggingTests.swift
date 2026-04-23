import XCTest
@testable import DeadMallTycoon

// v9 Prompt 4 Phase 2 coverage. Thoughts fired within the artifact proximity
// radius tag an artifact; thoughts outside the radius leave artifactId nil
// and draw from the personality pool.
//
// v9 Prompt 11 update:
//   - Coordinates updated for the post-v9-patch starting mall (kugel now
//     at y:700, not the pre-patch y:245 — the old test position was in
//     the upper access corridor, nowhere near any artifact).
//   - Proximity is now the ONLY gate — the Prompt 4 "25% generic fallback"
//     coin flip is gone. If an artifact is in range, the thought will
//     always tag it, so assertions tighten from "at least 1 of 20" to
//     "all 20 of 20."

final class ThoughtTaggingTests: XCTestCase {

    private func spawnVisitor(seed: UInt64 = 1) -> (Visitor, GameState) {
        let s = StartingMall.initialState()
        var rng = SeededGenerator(seed: seed)
        let v = VisitorFactory.spawn(state: s, rng: &rng)
        return (v, s)
    }

    func testThoughtNearArtifactTagsArtifact() {
        let (v, s) = spawnVisitor()
        // Seed mall has a kugel ball at (585, 700) per StartingMall
        // artifactSeeds. Position the visitor right at it (well inside
        // the 40pt radius). Under Prompt 11 rules, every call tags an
        // artifact when in proximity — no fallback coin flip.
        var rng = SeededGenerator(seed: 99)
        let thought = PersonalityPicker.pickThought(
            for: v, at: (x: 585, y: 700),
            in: s, rng: &rng
        )
        guard let id = thought.artifactId else {
            return XCTFail("expected tagged thought near kugel (within radius)")
        }
        let tagged = s.artifacts.first { $0.id == id }
        XCTAssertNotNil(tagged)
    }

    func testThoughtFarFromArtifactsLeavesTagNil() {
        let (v, s) = spawnVisitor()
        // Far corner of the world where nothing is near.
        var rng = SeededGenerator(seed: 1)
        let thought = PersonalityPicker.pickThought(
            for: v, at: (x: 10, y: 10),
            in: s, rng: &rng
        )
        XCTAssertNil(thought.artifactId,
                     "a thought fired far from any artifact must not carry an artifactId")
    }

    func testProximityRadiusBoundary() {
        // Position just outside vs just inside the radius of the kugel at
        // (585, 700). Radius is 40.
        let (v, s) = spawnVisitor()
        let insideX = 585 + ThoughtTuning.artifactProximityRadius - 5
        let outsideX = 585 + ThoughtTuning.artifactProximityRadius + 5

        // Under Prompt 11: every inside-radius attempt must tag; every
        // outside-radius attempt must not. No more fallback coin flip.
        var insideTags = 0
        var outsideTags = 0
        for seed in UInt64(1)...20 {
            var rng = SeededGenerator(seed: seed)
            let t = PersonalityPicker.pickThought(
                for: v, at: (x: insideX, y: 700),
                in: s, rng: &rng
            )
            if t.artifactId != nil { insideTags += 1 }
        }
        for seed in UInt64(1)...20 {
            var rng = SeededGenerator(seed: seed)
            let t = PersonalityPicker.pickThought(
                for: v, at: (x: outsideX, y: 700),
                in: s, rng: &rng
            )
            if t.artifactId != nil { outsideTags += 1 }
        }
        XCTAssertEqual(insideTags, 20,
                       "every inside-radius attempt tags an artifact — no fallback when nearby")
        XCTAssertEqual(outsideTags, 0,
                       "no outside-radius attempt should tag an artifact")
    }

    func testAmbientArtifactsAreNotProximityCandidates() {
        // boardedStorefront / sealedEntrance / etc. have nil x,y and must
        // never be "nearby" regardless of where the visitor stands.
        var s = StartingMall.initialState()
        // Spawn a boardedStorefront artifact with nil x/y.
        let boarded = ArtifactFactory.make(
            id: 9999, type: .boardedStorefront, name: "X",
            origin: .tenant(name: "Gone"),
            yearCreated: 1982,
            storeSlotId: 1
        )
        s.artifacts.append(boarded)

        let (v, _) = spawnVisitor()
        var rng = SeededGenerator(seed: 1)
        // Visitor position at (0,0) — kugel is far, ambient artifact has no position.
        let thought = PersonalityPicker.pickThought(
            for: v, at: (x: 0, y: 0),
            in: s, rng: &rng
        )
        XCTAssertNil(thought.artifactId,
                     "ambient artifacts (no x/y) must not be tagged in thought proximity")
    }
}
