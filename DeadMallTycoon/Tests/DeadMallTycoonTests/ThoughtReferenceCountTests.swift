import XCTest
@testable import DeadMallTycoon

// v9 Prompt 6 coverage. thoughtReferenceCount increments on every
// recordThoughtFired call regardless of cohort — it's a raw count, not a
// weighted signal. memoryWeight continues to accrue per cohort (Prompt 4).

final class ThoughtReferenceCountTests: XCTestCase {

    func testIncrementsByOneRegardlessOfCohort() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        guard let artifactId = vm.state.artifacts.first?.id else {
            return XCTFail("starting mall should seed at least one artifact")
        }

        vm.recordThoughtFired(artifactId: artifactId, cohort: .originals)
        vm.recordThoughtFired(artifactId: artifactId, cohort: .nostalgics)
        vm.recordThoughtFired(artifactId: artifactId, cohort: .explorers)

        let a = vm.state.artifacts.first { $0.id == artifactId }!
        XCTAssertEqual(a.thoughtReferenceCount, 3,
                       "count is raw: 3 thoughts → 3 increments, no cohort scaling")
    }

    func testMemoryWeightStillCohortWeightedAlongsideCount() {
        // Regression: the Prompt 4 cohort-weighted memoryWeight behavior
        // continues to work correctly when the count increment is layered on.
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        guard let artifactId = vm.state.artifacts.first?.id else {
            return XCTFail("starting mall should seed at least one artifact")
        }
        let beforeWeight = vm.state.artifacts.first { $0.id == artifactId }!.memoryWeight

        vm.recordThoughtFired(artifactId: artifactId, cohort: .originals)

        let a = vm.state.artifacts.first { $0.id == artifactId }!
        XCTAssertEqual(a.memoryWeight - beforeWeight, 1.25, accuracy: 0.001,
                       "original ×2.5 × base 0.5 = +1.25")
        XCTAssertEqual(a.thoughtReferenceCount, 1)
    }

    func testUnknownArtifactIdIsNoOp() {
        let vm = GameViewModel(seed: 1)
        vm.state = StartingMall.initialState()
        vm.recordThoughtFired(artifactId: 99999, cohort: .originals)
        for a in vm.state.artifacts {
            XCTAssertEqual(a.thoughtReferenceCount, 0)
            XCTAssertEqual(a.memoryWeight, 0)
        }
    }
}
