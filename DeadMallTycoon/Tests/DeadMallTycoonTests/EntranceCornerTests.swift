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

    func testSearsStretchedForFullScreenCorridor() {
        // v9 patch — worldHeight 1400. Anchors stretch to fill the corridor
        // (h:1000 spanning y:200..1200) so the H-shape walkable layout
        // stays proportional in the taller world.
        let s = StartingMall.initialState()
        let sears = s.stores.first { $0.name == "Sears" }
        XCTAssertNotNil(sears)
        XCTAssertEqual(sears?.position.x, 0)
        XCTAssertEqual(sears?.position.y, 200,
                       "Sears top at y:200 leaves a 110pt access corridor above")
        XCTAssertEqual(sears?.position.w, 200)
        XCTAssertEqual(sears?.position.h, 1000,
                       "Sears stretched to fill corridor in worldHeight 1400")
        XCTAssertGreaterThanOrEqual(sears?.position.w ?? 0, 180,
                                    "anchor-tier detection by w >= 180 must survive")
    }

    func testJCPenneyStretchedForFullScreenCorridor() {
        let s = StartingMall.initialState()
        let jcp = s.stores.first { $0.name == "JCPenney" }
        XCTAssertNotNil(jcp)
        XCTAssertEqual(jcp?.position.x, 1000)
        XCTAssertEqual(jcp?.position.y, 200)
        XCTAssertEqual(jcp?.position.w, 200)
        XCTAssertEqual(jcp?.position.h, 1000)
    }

    func testStorefrontsFlushToTopAndBottom() {
        // v9 patch — north row at y:0 (flush top edge of world), south row
        // at y:1310 (flush against bottom; stores h:90 → bottom at 1400).
        let s = StartingMall.initialState()
        let northStores = s.stores.filter { $0.wing == .north && $0.position.w < 180 }
        let southStores = s.stores.filter { $0.wing == .south && $0.position.w < 180 }
        XCTAssertFalse(northStores.isEmpty)
        XCTAssertFalse(southStores.isEmpty)
        for store in northStores {
            XCTAssertEqual(store.position.y, 0,
                           "north row stores flush against world top edge")
        }
        for store in southStores {
            XCTAssertEqual(store.position.y, 1310,
                           "south row stores flush against world bottom edge")
            XCTAssertEqual(store.position.y + store.position.h, 1400,
                           "south row bottom edge = world bottom (worldHeight 1400)")
        }
    }

    func testAccessCorridorStripsExist() {
        // 110pt walkable strips above/below anchors connect corner doors
        // to the main corridor without clipping anchors.
        let s = StartingMall.initialState()
        guard let sears = s.stores.first(where: { $0.name == "Sears" }) else {
            return XCTFail("Sears missing")
        }
        // North row bottom = y:90. Sears top = y:200. Gap = 110pt.
        let northRowBottom = 0.0 + 90.0
        let gapAbove = sears.position.y - northRowBottom
        XCTAssertEqual(gapAbove, 110,
                       "110pt access corridor between north row and west anchor")
        let gapBelow = 1310.0 - (sears.position.y + sears.position.h)
        XCTAssertEqual(gapBelow, 110,
                       "110pt access corridor between west anchor and south row")
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

    // v9 patch — coords updated for stretched world (worldHeight 1400):
    //   main corridor band y:200..1200, x:200..1000
    //   upper access lane y:145, lower access lane y:1255
    //   west gate x:210, east gate x:990

    func testMainCorridorToMainCorridorIsDirectOrDogleg() {
        let wp = MallScene.planPath(from: CGPoint(x: 400, y: 700),
                                     to: CGPoint(x: 800, y: 700))
        XCTAssertEqual(wp.count, 0, "straight-line horizontal in main corridor needs no waypoints")
    }

    func testMainCorridorToNorthStoreEmitsDogleg() {
        // Main corridor to north store approach at upper access lane y:145.
        let wp = MallScene.planPath(from: CGPoint(x: 500, y: 700),
                                     to: CGPoint(x: 250, y: 145))
        XCTAssertFalse(wp.isEmpty, "L-turn needed when x and y both change")
        XCTAssertEqual(wp.first!.x, 250,
                       "dogleg lands at target x first, then rises to target y")
    }

    func testNWCornerSpawnEscapesToAccessCorridor() {
        // Spawn inside NW corner block at y:30 (door position).
        let wp = MallScene.planPath(from: CGPoint(x: 100, y: 30),
                                     to: CGPoint(x: 500, y: 700))
        XCTAssertFalse(wp.isEmpty)
        // First waypoint must be at upper-access lane y to escape the corner block.
        XCTAssertEqual(wp.first!.y, 145)
    }

    func testNWSpawnToNorthStoreRoutesViaUpperAccess() {
        let wp = MallScene.planPath(from: CGPoint(x: 100, y: 145),
                                     to: CGPoint(x: 250, y: 145))
        XCTAssertTrue(wp.contains(where: { $0.x == 210 && $0.y == 145 }),
                      "must slide to west gate (x=210) before reaching target x")
    }

    func testNWSpawnToSouthStoreRoutesThroughBothAccessCorridors() {
        let wp = MallScene.planPath(from: CGPoint(x: 100, y: 145),
                                     to: CGPoint(x: 700, y: 1255))
        XCTAssertTrue(wp.contains(where: { $0.x == 210 && $0.y == 145 }),
                      "enters main corridor via west gate")
        XCTAssertTrue(wp.contains(where: { $0.x == 700 && $0.y == 145 }),
                      "dogleg at target x in upper access before vertical drop")
    }

    func testCornerToOppositeCornerCrossesMallViaAccessCorridors() {
        // NW spawn to SE corner block (y:1370 = SE door position).
        let wp = MallScene.planPath(from: CGPoint(x: 100, y: 145),
                                     to: CGPoint(x: 1100, y: 1370))
        // No waypoint may lie inside an anchor rect (x:0..200 or x:1000..1200
        // intersected with y:200..1200).
        for p in wp {
            let inWestAnchorRect = p.x >= 0 && p.x < 200 && p.y >= 200 && p.y <= 1200
            let inEastAnchorRect = p.x > 1000 && p.x <= 1200 && p.y >= 200 && p.y <= 1200
            XCTAssertFalse(inWestAnchorRect, "waypoint \(p) lies inside Sears")
            XCTAssertFalse(inEastAnchorRect, "waypoint \(p) lies inside JCPenney")
        }
    }

    func testPathPlanningSkipsZeroLengthStep() {
        let wp = MallScene.planPath(from: CGPoint(x: 500, y: 700),
                                     to: CGPoint(x: 500, y: 700))
        XCTAssertEqual(wp.count, 0)
    }
}
