import XCTest
@testable import DeadMallTycoon

// v9 Prompt 6.5 coverage. Four corner entrances (NW/NE/SW/SE) replace the
// two wing-centered doors. Corner-to-wing mapping is fixed; wing closure
// hides both corners on that wing; per-corner sealing is additive.
// Diminishing-returns traffic multiplier scales with open-door count.

// MARK: - EntranceCorner / wing mapping

final class EntranceCornerWingTests: XCTestCase {

    func testCornerWingMapping() {
        XCTAssertEqual(EntranceCorner.nw.wing, .north)
        XCTAssertEqual(EntranceCorner.ne.wing, .north)
        XCTAssertEqual(EntranceCorner.sw.wing, .south)
        XCTAssertEqual(EntranceCorner.se.wing, .south)
    }

    func testAllCornersEnumerated() {
        XCTAssertEqual(Set(EntranceCorner.allCases), [.nw, .ne, .sw, .se])
    }
}

// MARK: - Mall.openEntrances

final class OpenEntrancesTests: XCTestCase {

    func testFreshMallFourOpen() {
        let s = StartingMall.initialState()
        XCTAssertEqual(Mall.openEntranceCount(in: s), 4)
        XCTAssertEqual(Mall.openEntrances(in: s), [.nw, .ne, .sw, .se])
    }

    func testPerCornerSealRemovesOneFromOpen() {
        var s = StartingMall.initialState()
        s.sealedEntrances.insert(.nw)
        XCTAssertEqual(Mall.openEntranceCount(in: s), 3)
        XCTAssertFalse(Mall.openEntrances(in: s).contains(.nw))
    }

    func testWingClosedHidesBothItsCorners() {
        var s = StartingMall.initialState()
        s.wingsClosed[.north] = true
        let open = Mall.openEntrances(in: s)
        XCTAssertFalse(open.contains(.nw))
        XCTAssertFalse(open.contains(.ne))
        XCTAssertTrue(open.contains(.sw))
        XCTAssertTrue(open.contains(.se))
        XCTAssertEqual(Mall.openEntranceCount(in: s), 2)
    }

    func testWingClosureAndSealCombine() {
        var s = StartingMall.initialState()
        s.wingsClosed[.north] = true
        s.sealedEntrances.insert(.sw)
        // NW+NE hidden by wing, SW sealed → only SE open.
        XCTAssertEqual(Mall.openEntrances(in: s), [.se])
    }
}

// MARK: - Traffic multiplier curve

final class EntranceTrafficMultiplierTests: XCTestCase {

    func testCurveValues() {
        XCTAssertEqual(Economy.entranceTrafficMultiplier(openEntranceCount: 0), 0.0)
        XCTAssertEqual(Economy.entranceTrafficMultiplier(openEntranceCount: 1), 0.5)
        XCTAssertEqual(Economy.entranceTrafficMultiplier(openEntranceCount: 2), 1.0,
                       "two open is the baseline — matches pre-6.5 two-wing magnitudes")
        XCTAssertEqual(Economy.entranceTrafficMultiplier(openEntranceCount: 3), 1.2)
        XCTAssertEqual(Economy.entranceTrafficMultiplier(openEntranceCount: 4), 1.4)
    }

    func testOutOfRangeClampsToMax() {
        // Topology is fixed at 4 corners, but the switch's default branch
        // must not return 0 for unexpected counts — clamp high.
        XCTAssertEqual(Economy.entranceTrafficMultiplier(openEntranceCount: 5), 1.4)
        XCTAssertEqual(Economy.entranceTrafficMultiplier(openEntranceCount: 99), 1.4)
    }
}

// MARK: - Anchor geometry regression

final class AnchorGeometryTests: XCTestCase {

    func testSearsRelocatedToCorridorFlank() {
        let s = StartingMall.initialState()
        let sears = s.stores.first { $0.name == "Sears" }
        XCTAssertNotNil(sears)
        XCTAssertEqual(sears?.position.x, 0)
        XCTAssertEqual(sears?.position.y, 110, "Sears no longer full-scene-height bookend")
        XCTAssertEqual(sears?.position.w, 200)
        XCTAssertEqual(sears?.position.h, 300)
        XCTAssertGreaterThanOrEqual(sears?.position.w ?? 0, 180,
                                    "anchor-tier detection by w >= 180 must survive")
    }

    func testJCPenneyRelocatedToCorridorFlank() {
        let s = StartingMall.initialState()
        let jcp = s.stores.first { $0.name == "JCPenney" }
        XCTAssertNotNil(jcp)
        XCTAssertEqual(jcp?.position.x, 1000)
        XCTAssertEqual(jcp?.position.y, 110)
        XCTAssertEqual(jcp?.position.w, 200)
        XCTAssertEqual(jcp?.position.h, 300)
    }
}
