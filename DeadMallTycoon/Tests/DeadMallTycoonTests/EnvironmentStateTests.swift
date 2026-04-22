import XCTest
@testable import DeadMallTycoon

// v9 Prompt 8 coverage. EnvironmentState resolves from (Mall.state,
// monthsInDeadState). ghostMall transition at 60 consecutive months in
// dead; recovery resets the counter. Tuning tables match spec.

// MARK: - Helpers

/// Mutate a starting mall so Mall.state(...) returns the requested band.
/// Uses occupancy ratio: drop tenants until the ratio falls into the target
/// range. thriving ≥0.85, fading ≥0.65, struggling ≥0.40, dying ≥0.20,
/// dead <0.20.
private func mallInBand(_ target: MallState) -> GameState {
    var s = StartingMall.initialState()
    // Target occupancy ratios per band, picked at the middle of each range.
    let r: Double = {
        switch target {
        case .thriving:   return 0.90
        case .fading:     return 0.75
        case .struggling: return 0.50
        case .dying:      return 0.30
        case .dead:       return 0.05
        }
    }()
    let total = s.stores.count
    let targetOccupied = Int(Double(total) * r)
    var currentOccupied = s.stores.filter { $0.tier != .vacant }.count
    var i = 0
    while currentOccupied > targetOccupied && i < s.stores.count {
        if s.stores[i].tier != .vacant {
            s.stores[i] = Store.vacant(id: s.stores[i].id, at: s.stores[i].position)
            currentOccupied -= 1
        }
        i += 1
    }
    return s
}

// MARK: - Resolver

final class EnvironmentStateResolverTests: XCTestCase {

    func testResolvesEachMallBandToMatchingEnvState() {
        let bands: [(MallState, EnvironmentState)] = [
            (.thriving, .thriving),
            (.fading, .fading),
            (.struggling, .struggling),
            (.dying, .dying),
            (.dead, .dead),
        ]
        for (band, expected) in bands {
            var s = mallInBand(band)
            s.monthsInDeadState = 0
            let env = EnvironmentState.from(s)
            XCTAssertEqual(env, expected,
                           "band \(band) must resolve to \(expected)")
        }
    }

    func testGhostMallTriggersAt60MonthsInDead() {
        var s = mallInBand(.dead)
        s.monthsInDeadState = 59
        XCTAssertEqual(EnvironmentState.from(s), .dead,
                       "59 months = still dead, not yet ghost")
        s.monthsInDeadState = 60
        XCTAssertEqual(EnvironmentState.from(s), .ghostMall,
                       "60 months = ghostMall transition fires")
    }

    func testGhostMallOnlyWhenActuallyDead() {
        // Counter should never stick when the band is non-dead.
        var s = mallInBand(.dying)
        s.monthsInDeadState = 120   // stale but non-dead band
        XCTAssertEqual(EnvironmentState.from(s), .dying,
                       "non-dead band never resolves to ghostMall even with large counter")
    }
}

// MARK: - TickEngine counter behavior

final class MonthsInDeadCounterTests: XCTestCase {

    func testCounterIncrementsWhileDead() {
        var s = mallInBand(.dead)
        s.currentTraffic = 100  // avoid scoring gate
        var rng = SeededGenerator(seed: 1)
        let before = s.monthsInDeadState
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertEqual(s.monthsInDeadState, before + 1)
    }

    func testCounterResetsOnRecovery() {
        var s = mallInBand(.dead)
        s.currentTraffic = 100
        s.monthsInDeadState = 40
        // Re-populate a tenant so state ratio rises out of dead.
        for i in s.stores.indices where s.stores[i].tier == .vacant {
            s.stores[i].tier = .standard
            break   // just one — enough to leave dead band
        }
        // Verify we are no longer in dead band.
        if Mall.state(s) == .dead {
            // Boost more if needed.
            for i in s.stores.indices where s.stores[i].tier == .vacant {
                s.stores[i].tier = .standard
                if Mall.state(s) != .dead { break }
            }
        }
        XCTAssertNotEqual(Mall.state(s), .dead,
                          "test setup must leave dead band before ticking")
        var rng = SeededGenerator(seed: 1)
        s = TickEngine.tick(s, rng: &rng)
        XCTAssertEqual(s.monthsInDeadState, 0,
                       "recovery must zero the counter")
    }
}

// MARK: - Tuning tables

final class EnvironmentTuningTests: XCTestCase {

    func testBrightnessMultipliersMatchSpec() {
        XCTAssertEqual(EnvironmentTuning.brightnessMultipliers[.thriving],   1.0)
        XCTAssertEqual(EnvironmentTuning.brightnessMultipliers[.fading],     0.92)
        XCTAssertEqual(EnvironmentTuning.brightnessMultipliers[.struggling], 0.8)
        XCTAssertEqual(EnvironmentTuning.brightnessMultipliers[.dying],      0.65)
        XCTAssertEqual(EnvironmentTuning.brightnessMultipliers[.dead],       0.5)
        XCTAssertEqual(EnvironmentTuning.brightnessMultipliers[.ghostMall],  0.4)
    }

    func testSaturationMultipliersMatchSpec() {
        XCTAssertEqual(EnvironmentTuning.saturationMultipliers[.thriving],   1.0)
        XCTAssertEqual(EnvironmentTuning.saturationMultipliers[.fading],     0.85)
        XCTAssertEqual(EnvironmentTuning.saturationMultipliers[.struggling], 0.7)
        XCTAssertEqual(EnvironmentTuning.saturationMultipliers[.dying],      0.55)
        XCTAssertEqual(EnvironmentTuning.saturationMultipliers[.dead],       0.4)
        XCTAssertEqual(EnvironmentTuning.saturationMultipliers[.ghostMall],  0.25)
    }

    func testFluorescentFlickerRateMatchesSpec() {
        XCTAssertEqual(EnvironmentTuning.fluorescentFlickerRate[.thriving],   0.0)
        XCTAssertEqual(EnvironmentTuning.fluorescentFlickerRate[.fading],     0.02)
        XCTAssertEqual(EnvironmentTuning.fluorescentFlickerRate[.struggling], 0.08)
        XCTAssertEqual(EnvironmentTuning.fluorescentFlickerRate[.dying],      0.2)
        XCTAssertEqual(EnvironmentTuning.fluorescentFlickerRate[.dead],       0.35)
        XCTAssertEqual(EnvironmentTuning.fluorescentFlickerRate[.ghostMall],  0.5)
    }

    func testIsolationThresholdIsFour() {
        XCTAssertEqual(EnvironmentTuning.isolationThreshold, 4)
    }

    func testGhostMallThresholdIsSixtyMonths() {
        XCTAssertEqual(EnvironmentTuning.monthsInDeadForGhostMall, 60)
    }

    func testEveryStateCoveredInEveryTable() {
        for env in EnvironmentState.allCases {
            XCTAssertNotNil(EnvironmentTuning.brightnessMultipliers[env],
                            "brightness table missing \(env)")
            XCTAssertNotNil(EnvironmentTuning.saturationMultipliers[env],
                            "saturation table missing \(env)")
            XCTAssertNotNil(EnvironmentTuning.fluorescentFlickerRate[env],
                            "flicker table missing \(env)")
            XCTAssertNotNil(EnvironmentTuning.ambientHumVolume[env],
                            "ambient hum table missing \(env)")
        }
    }
}
