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

    // v9 Prompt 2 update: the Prompt 1 "TickEngine does not mutate artifacts"
    // invariant is superseded — TickEngine now routes tenant closure through
    // TenantLifecycle.vacateSlot which spawns boardedStorefront artifacts.
    // Equivalent-but-correct coverage lives in ArtifactSpawnTests.swift:
    //   - testNoClosuresMeansNoArtifactsInPrompt2 — a healthy-tenant mall
    //     still produces no artifacts (no closure path taken).
    //   - testArtifactSpawnIsDeterministicUnderSameSeed — same-seed determinism.
    //
    // The "preserve an existing artifact across ticks" check is covered by
    // the deterministic-seed test in the spawn suite (appended artifacts
    // survive tick).
    //
    // Prompt 1-era assertions that expected state.artifacts to stay empty
    // across arbitrary ticks would flake as soon as an RNG-driven closure
    // fired; retired deliberately.
}
