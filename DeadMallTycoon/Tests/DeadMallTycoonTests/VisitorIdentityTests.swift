import XCTest
@testable import DeadMallTycoon

// v9 Prompt 4 Phase 1 coverage. Visitor spawn must always populate the new
// identity fields (firstName, lastName, ageCohort, mood, activity,
// destinationIntent). tenantIdAffinity stays nil — it's reserved for a
// later prompt.

final class VisitorIdentityTests: XCTestCase {

    private func spawn(seed: UInt64 = 1) -> Visitor {
        let s = StartingMall.initialState()
        var rng = SeededGenerator(seed: seed)
        return VisitorFactory.spawn(state: s, rng: &rng)
    }

    func testSpawnPopulatesFirstAndLastName() {
        let v = spawn()
        XCTAssertFalse(v.firstName.isEmpty)
        XCTAssertFalse(v.lastName.isEmpty)
        XCTAssertEqual(v.name, "\(v.firstName) \(v.lastName)")
    }

    func testSpawnPicksNameFromPeriodPool() {
        // Over 100 spawns, the chosen names should all be in VisitorNames.
        var rng = SeededGenerator(seed: 42)
        let s = StartingMall.initialState()
        for _ in 0..<100 {
            let v = VisitorFactory.spawn(state: s, rng: &rng)
            XCTAssertTrue(VisitorNames.firstNames.contains(v.firstName),
                           "first name '\(v.firstName)' not in VisitorNames pool")
            XCTAssertTrue(VisitorNames.lastNames.contains(v.lastName),
                           "last name '\(v.lastName)' not in VisitorNames pool")
        }
    }

    func testAgeCohortDerivesFromAge() {
        // Spawn many; assert cohort always matches derivation rule.
        var rng = SeededGenerator(seed: 7)
        let s = StartingMall.initialState()
        for _ in 0..<200 {
            let v = VisitorFactory.spawn(state: s, rng: &rng)
            XCTAssertEqual(v.ageCohort, AgeCohort.from(age: v.age))
        }
    }

    func testCohortBucketBoundaries() {
        XCTAssertEqual(AgeCohort.from(age:  5),  .explorers)   // kid → explorers
        XCTAssertEqual(AgeCohort.from(age: 14),  .explorers)
        XCTAssertEqual(AgeCohort.from(age: 15),  .explorers)
        XCTAssertEqual(AgeCohort.from(age: 29),  .explorers)
        XCTAssertEqual(AgeCohort.from(age: 30),  .nostalgics)
        XCTAssertEqual(AgeCohort.from(age: 55),  .nostalgics)
        XCTAssertEqual(AgeCohort.from(age: 56),  .originals)
        XCTAssertEqual(AgeCohort.from(age: 82),  .originals)
    }

    func testCohortMultipliers() {
        XCTAssertEqual(AgeCohort.explorers.memoryWeightMultiplier, 1.0, accuracy: 0.001)
        XCTAssertEqual(AgeCohort.nostalgics.memoryWeightMultiplier, 1.5, accuracy: 0.001)
        XCTAssertEqual(AgeCohort.originals.memoryWeightMultiplier, 2.5, accuracy: 0.001)
    }

    func testSpawnPopulatesMoodActivityDestination() {
        // These are non-nil at spawn (enum, not optional), but verify via
        // allCases membership that the spawn produces valid values.
        var rng = SeededGenerator(seed: 11)
        let s = StartingMall.initialState()
        for _ in 0..<50 {
            let v = VisitorFactory.spawn(state: s, rng: &rng)
            XCTAssertTrue(VisitorMood.allCases.contains(v.mood))
            XCTAssertTrue(VisitorActivity.allCases.contains(v.activity))
            // DestinationIntent — ensure it's one of the known cases.
            switch v.destinationIntent {
            case .fountain, .foodCourt, .directory, .store, .nearestExit, .noDestination:
                break
            }
        }
    }

    func testSpawnLeavesTenantIdAffinityNil() {
        // Schema reserved; no mechanic in Prompt 4 populates it.
        var rng = SeededGenerator(seed: 9)
        let s = StartingMall.initialState()
        for _ in 0..<20 {
            let v = VisitorFactory.spawn(state: s, rng: &rng)
            XCTAssertNil(v.tenantIdAffinity)
        }
    }

    func testNamePoolSizes() {
        // Spec: 75 first names, 40 last names.
        XCTAssertEqual(VisitorNames.firstNames.count, 75)
        XCTAssertEqual(VisitorNames.lastNames.count, 40)
    }

    func testVisitorIdentitySnapshot() {
        var rng = SeededGenerator(seed: 55)
        let s = StartingMall.initialState()
        let v = VisitorFactory.spawn(state: s, rng: &rng)
        let snapshot = VisitorIdentity(from: v, memory: "test memory")
        XCTAssertEqual(snapshot.firstName, v.firstName)
        XCTAssertEqual(snapshot.lastName, v.lastName)
        XCTAssertEqual(snapshot.ageCohort, v.ageCohort)
        XCTAssertEqual(snapshot.lastMemory, "test memory")
    }
}
