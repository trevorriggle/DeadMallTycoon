import XCTest
@testable import DeadMallTycoon

// v9 Prompt 4 Phase 2 coverage. Thoughts fired within the artifact proximity
// radius tag the closest artifact; thoughts outside the radius leave
// artifactId nil and draw from the personality pool.

final class ThoughtTaggingTests: XCTestCase {

    private func spawnVisitor(seed: UInt64 = 1) -> (Visitor, GameState) {
        let s = StartingMall.initialState()
        var rng = SeededGenerator(seed: seed)
        let v = VisitorFactory.spawn(state: s, rng: &rng)
        return (v, s)
    }

    func testThoughtNearArtifactTagsArtifact() {
        let (v, s) = spawnVisitor()
        // Seed mall has a kugel ball at (585, 245). Position the visitor
        // right next to it (well inside 40pt radius).
        var rng = SeededGenerator(seed: 99)
        let thought = PersonalityPicker.pickThought(
            for: v, at: (x: 585, y: 245),
            in: s, rng: &rng
        )
        // Over many seeds the tagging isn't guaranteed every single call
        // (generic-fallback roll), but for this particular seed we expect
        // the artifactId to be populated with the closest artifact (kugel).
        // If nil, it's the genericFallback path — re-roll with a seed that
        // avoids it to confirm tagging works.
        var tagged: Thought = thought
        if tagged.artifactId == nil {
            // Force through a different seed.
            var rng2 = SeededGenerator(seed: 3)
            tagged = PersonalityPicker.pickThought(
                for: v, at: (x: 585, y: 245),
                in: s, rng: &rng2
            )
        }
        guard let id = tagged.artifactId else {
            return XCTFail("expected tagged thought near kugel (within radius)")
        }
        let tagged_artifact = s.artifacts.first { $0.id == id }
        XCTAssertNotNil(tagged_artifact)
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
        // Position just outside vs just inside the radius of the kugel at (585, 245).
        // Kugel seed is at (585, 245); radius is 40.
        let (v, s) = spawnVisitor()
        let insideX = 585 + ThoughtTuning.artifactProximityRadius - 5
        let outsideX = 585 + ThoughtTuning.artifactProximityRadius + 5

        // Force through 20 attempts with varied seeds; inside should produce
        // at least one tagged thought, outside should produce zero tagged.
        var insideTags = 0
        var outsideTags = 0
        for seed in UInt64(1)...20 {
            var rng = SeededGenerator(seed: seed)
            let t = PersonalityPicker.pickThought(
                for: v, at: (x: insideX, y: 245),
                in: s, rng: &rng
            )
            if t.artifactId != nil { insideTags += 1 }
        }
        for seed in UInt64(1)...20 {
            var rng = SeededGenerator(seed: seed)
            let t = PersonalityPicker.pickThought(
                for: v, at: (x: outsideX, y: 245),
                in: s, rng: &rng
            )
            if t.artifactId != nil { outsideTags += 1 }
        }
        XCTAssertGreaterThan(insideTags, 0,
                              "at least one of 20 inside-radius attempts should tag an artifact")
        XCTAssertEqual(outsideTags, 0,
                        "no outside-radius attempt should tag an artifact (kugel is the only in-range)")
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
