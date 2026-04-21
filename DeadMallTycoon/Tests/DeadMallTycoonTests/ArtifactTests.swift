import XCTest
@testable import DeadMallTycoon

// v9: Prompt 1 coverage. Artifact is introduced as a model-only entity; no
// existing mechanic should read or write GameState.artifacts yet. These tests
// pin that invariant (the regression guard) plus the factory defaults.

final class ArtifactFactoryTests: XCTestCase {

    func testFactoryDefaultsConditionAndWeightToZero() {
        let a = ArtifactFactory.make(
            id: 1,
            type: .boardedStorefront,
            name: "Closed: Hot Topic",
            origin: .tenant(name: "Hot Topic"),
            yearCreated: 1985
        )
        XCTAssertEqual(a.condition, 0)
        XCTAssertEqual(a.memoryWeight, 0)
        XCTAssertEqual(a.yearCreated, 1985)
        XCTAssertEqual(a.name, "Closed: Hot Topic")
        XCTAssertEqual(a.type, .boardedStorefront)
    }

    func testFactoryPopulatesTypeSpecificTriggerPool() {
        // Each preset type should ship with a non-empty placeholder pool. This
        // also guards against adding a new ArtifactType case without wiring it
        // into defaultThoughtTriggers(for:) — the switch is exhaustive, but an
        // accidentally-empty array would slip past the compiler.
        for type in ArtifactType.allCases {
            let a = ArtifactFactory.make(
                id: 0,
                type: type,
                name: "x",
                origin: .event(name: "Test"),
                yearCreated: 1982
            )
            XCTAssertFalse(a.thoughtTriggers.isEmpty,
                           "type \(type) must have default thought triggers")
        }
    }

    func testFactoryRespectsExplicitTriggerOverride() {
        let custom = ["one", "two"]
        let a = ArtifactFactory.make(
            id: 0,
            type: .custom,
            name: "Weird Thing",
            origin: .playerAction("scripted"),
            yearCreated: 1990,
            thoughtTriggers: custom
        )
        XCTAssertEqual(a.thoughtTriggers, custom)
    }

    func testOriginEnumDiscriminates() {
        // Pattern-match sanity — Prompt 9 relies on this for cascade generation.
        let tenant = ArtifactFactory.make(id: 1, type: .boardedStorefront,
                                           name: "n", origin: .tenant(name: "Sears"),
                                           yearCreated: 1982)
        let event  = ArtifactFactory.make(id: 2, type: .waterStainedCeiling,
                                           name: "n", origin: .event(name: "Burst Pipes"),
                                           yearCreated: 1983)
        let player = ArtifactFactory.make(id: 3, type: .sealedEntrance,
                                           name: "n", origin: .playerAction("sealed wing"),
                                           yearCreated: 1984)
        if case .tenant(let who) = tenant.origin { XCTAssertEqual(who, "Sears") }
        else { XCTFail("expected tenant origin") }
        if case .event(let who) = event.origin { XCTAssertEqual(who, "Burst Pipes") }
        else { XCTFail("expected event origin") }
        if case .playerAction(let what) = player.origin { XCTAssertEqual(what, "sealed wing") }
        else { XCTFail("expected playerAction origin") }
    }
}

final class ArtifactCodableTests: XCTestCase {

    func testArtifactRoundTripsThroughCodable() throws {
        let original = ArtifactFactory.make(
            id: 42,
            type: .stoppedFountain,
            name: "East fountain",
            origin: .tenant(name: "Orange Julius"),
            yearCreated: 1987,
            thoughtTriggers: ["a", "b", "c"]
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Artifact.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testOriginEnumRoundTripsForAllCases() throws {
        let origins: [ArtifactOrigin] = [
            .tenant(name: "Sears"),
            .event(name: "Burst Pipes"),
            .playerAction("sealed north wing"),
        ]
        for origin in origins {
            let a = ArtifactFactory.make(id: 0, type: .custom, name: "n",
                                          origin: origin, yearCreated: 1982)
            let data = try JSONEncoder().encode(a)
            let back = try JSONDecoder().decode(Artifact.self, from: data)
            XCTAssertEqual(back.origin, origin)
        }
    }
}

final class ArtifactGameStateIntegrationTests: XCTestCase {

    func testNewGameStateHasEmptyArtifacts() {
        let s = GameState()
        XCTAssertTrue(s.artifacts.isEmpty)
    }

    func testStartingMallHasEmptyArtifacts() {
        let s = StartingMall.initialState()
        XCTAssertTrue(s.artifacts.isEmpty,
                      "Prompt 1 does not seed artifacts. Later prompts add the closure pipeline.")
    }

    // Regression guard: if any later prompt quietly wires a mechanic into
    // state.artifacts before its own prompt, this test fails and the offending
    // change is visible. A year of ticks with a seeded RNG must not mutate the
    // artifact list in Prompt 1.
    func testTickEngineDoesNotMutateArtifactsInPrompt1() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        var rng = SeededGenerator(seed: 17)
        for _ in 0..<24 {
            s = TickEngine.tick(s, rng: &rng)
            if s.decision != nil { s.decision = nil; s.paused = false }
        }
        XCTAssertTrue(s.artifacts.isEmpty,
                      "no code path in Prompt 1 should write to state.artifacts")
    }

    // Direct-insert sanity: manually adding an Artifact should round-trip
    // through tick and remain unchanged (proving the field is inert, not
    // accidentally cleared by some unrelated reset).
    func testArtifactsArePreservedAcrossTicks() {
        var s = StartingMall.initialState()
        s.pendingLawsuitMonth = nil
        s.artifacts.append(ArtifactFactory.make(
            id: 1, type: .flickeringNeon,
            name: "Marquee Neon",
            origin: .event(name: "Seed"),
            yearCreated: 1982
        ))
        var rng = SeededGenerator(seed: 31)
        for _ in 0..<12 {
            s = TickEngine.tick(s, rng: &rng)
            if s.decision != nil { s.decision = nil; s.paused = false }
        }
        XCTAssertEqual(s.artifacts.count, 1)
        XCTAssertEqual(s.artifacts.first?.id, 1)
        XCTAssertEqual(s.artifacts.first?.condition, 0,
                       "Prompt 1 does not age artifacts; decay wiring comes later")
        XCTAssertEqual(s.artifacts.first?.memoryWeight, 0,
                       "Prompt 1 does not accumulate weight; accumulation comes later")
    }
}
