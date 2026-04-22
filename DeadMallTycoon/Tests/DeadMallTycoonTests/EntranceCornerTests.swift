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
        XCTAssertEqual(sears?.position.y, 140,
                       "Sears top at y:140 leaves a 30pt access corridor above the anchor")
        XCTAssertEqual(sears?.position.w, 200)
        XCTAssertEqual(sears?.position.h, 240,
                       "Sears height 240 = main corridor height minus two 30pt access strips")
        XCTAssertGreaterThanOrEqual(sears?.position.w ?? 0, 180,
                                    "anchor-tier detection by w >= 180 must survive")
    }

    func testJCPenneyRelocatedToCorridorFlank() {
        let s = StartingMall.initialState()
        let jcp = s.stores.first { $0.name == "JCPenney" }
        XCTAssertNotNil(jcp)
        XCTAssertEqual(jcp?.position.x, 1000)
        XCTAssertEqual(jcp?.position.y, 140)
        XCTAssertEqual(jcp?.position.w, 200)
        XCTAssertEqual(jcp?.position.h, 240)
    }

    func testAccessCorridorStripsExist() {
        // The 30pt walkable strips above/below anchors are what make corner
        // doors reachable from the main corridor without clipping anchors.
        let s = StartingMall.initialState()
        guard let sears = s.stores.first(where: { $0.name == "Sears" }) else {
            return XCTFail("Sears missing")
        }
        // North row bottom = y:110. Sears top = y:140. Gap = 30pt.
        let northRowBottom = 20.0 + 90.0
        let gapAbove = sears.position.y - northRowBottom
        XCTAssertEqual(gapAbove, 30,
                       "30pt access corridor between north row and west anchor")
        let gapBelow = 410.0 - (sears.position.y + sears.position.h)
        XCTAssertEqual(gapBelow, 30,
                       "30pt access corridor between west anchor and south row")
    }
}

// MARK: - ArtifactPathingClass (v9 Prompt 6.5 fix)

final class ArtifactPathingClassTests: XCTestCase {

    func testEveryArtifactTypeClassified() {
        // Regression guard: adding an ArtifactType without a catalog entry
        // crashes here. info(_:) is exhaustive; this just touches the field.
        for type in ArtifactType.allCases {
            let cls = ArtifactCatalog.pathingClass(for: type)
            XCTAssertTrue(ArtifactPathingClass.allCases.contains(cls),
                          "type \(type) has no valid pathing class")
        }
    }

    func testObstacleClassificationForKnownObstacles() {
        // The avoidance system runs specifically on these. If one of them
        // gets accidentally reclassified, visitors will walk through it.
        let obstacles: [ArtifactType] = [
            .kugelBall, .fountain, .bench, .directoryBoard,
            .photoBooth, .arcadeCabinet, .payPhoneBank,
        ]
        for t in obstacles {
            XCTAssertEqual(ArtifactCatalog.pathingClass(for: t), .obstacle,
                           "\(t) should be .obstacle")
        }
    }

    func testFloorClassificationForFloorTextures() {
        let floors: [ArtifactType] = [.terrazzoFlooring, .terrazzoInlay, .crackedTile]
        for t in floors {
            XCTAssertEqual(ArtifactCatalog.pathingClass(for: t), .floor,
                           "\(t) should be .floor — visitors walk over")
        }
    }

    func testCeilingClassificationForOverheadFixtures() {
        let ceilings: [ArtifactType] = [
            .skylight, .waterStainedCeiling, .flickeringFluorescent, .emergencyExitSign,
        ]
        for t in ceilings {
            XCTAssertEqual(ArtifactCatalog.pathingClass(for: t), .ceiling,
                           "\(t) should be .ceiling — above pedestrian level")
        }
    }
}

// MARK: - planPath (v9 Prompt 6.5 fix)

final class PathPlanningTests: XCTestCase {

    func testMainCorridorToMainCorridorIsDirectOrDogleg() {
        // Same y: no bends.
        let wp = MallScene.planPath(from: CGPoint(x: 400, y: 260),
                                     to: CGPoint(x: 800, y: 260))
        XCTAssertEqual(wp.count, 0, "straight-line horizontal in main corridor needs no waypoints")
    }

    func testMainCorridorToNorthStoreEmitsDogleg() {
        // Main corridor to north store approach (at y:125 in upper access).
        let wp = MallScene.planPath(from: CGPoint(x: 500, y: 260),
                                     to: CGPoint(x: 250, y: 125))
        XCTAssertFalse(wp.isEmpty, "L-turn needed when x and y both change")
        XCTAssertEqual(wp.first!.x, 250,
                       "dogleg lands at target x first, then drops to target y")
    }

    func testNWCornerSpawnEscapesToAccessCorridor() {
        // Spawn inside NW corner block (e.g. at y:70 — hypothetical, not used today).
        let wp = MallScene.planPath(from: CGPoint(x: 100, y: 70),
                                     to: CGPoint(x: 500, y: 260))
        XCTAssertFalse(wp.isEmpty)
        // First waypoint must be at upper-access Y to get out of the corner block.
        XCTAssertEqual(wp.first!.y, 125)
    }

    func testNWSpawnToNorthStoreRoutesViaUpperAccess() {
        // Spawn-at-door (in upper access) to a north store approach.
        let wp = MallScene.planPath(from: CGPoint(x: 100, y: 125),
                                     to: CGPoint(x: 250, y: 125))
        // Must hit the main-corridor west gate on the way.
        XCTAssertTrue(wp.contains(where: { $0.x == 210 && $0.y == 125 }),
                      "must slide to west gate (x=210) before reaching target x")
    }

    func testNWSpawnToSouthStoreRoutesThroughBothAccessCorridors() {
        let wp = MallScene.planPath(from: CGPoint(x: 100, y: 125),
                                     to: CGPoint(x: 700, y: 395))
        XCTAssertTrue(wp.contains(where: { $0.x == 210 && $0.y == 125 }),
                      "enters main corridor via west gate")
        // Final dogleg: waypoint at (700, 125) so we drop vertically at target x.
        XCTAssertTrue(wp.contains(where: { $0.x == 700 && $0.y == 125 }),
                      "dogleg at target x in upper access before vertical drop")
    }

    func testCornerToOppositeCornerCrossesMallViaAccessCorridors() {
        // NW spawn to SE corner block (hypothetical y>410).
        let wp = MallScene.planPath(from: CGPoint(x: 100, y: 125),
                                     to: CGPoint(x: 1100, y: 460))
        // Must slide to west gate, then drop down in main corridor at x=210 or
        // transition via lower access at east side. Verify we don't pass
        // through x:0..200 OR x:1000..1200 while at y:140..380 (anchor rects).
        for p in wp {
            let inWestAnchorRect = p.x >= 0 && p.x < 200 && p.y >= 140 && p.y <= 380
            let inEastAnchorRect = p.x > 1000 && p.x <= 1200 && p.y >= 140 && p.y <= 380
            XCTAssertFalse(inWestAnchorRect, "waypoint \(p) lies inside Sears")
            XCTAssertFalse(inEastAnchorRect, "waypoint \(p) lies inside JCPenney")
        }
    }

    func testPathPlanningSkipsZeroLengthStep() {
        // Source == target should return empty.
        let wp = MallScene.planPath(from: CGPoint(x: 500, y: 260),
                                     to: CGPoint(x: 500, y: 260))
        XCTAssertEqual(wp.count, 0)
    }
}
