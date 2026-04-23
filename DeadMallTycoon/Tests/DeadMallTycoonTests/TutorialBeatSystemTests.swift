import XCTest
@testable import DeadMallTycoon

// v9 Prompt 18 — tutorial beat system coverage.
//
// Five slices:
//   1. Gate + one-shot contract: tutorialEnabled guards every trigger,
//      and a beat fires at most once per run (tutorialBeatsSeen).
//   2. Detector triggers: each detector-visible beat fires from the
//      state condition it's supposed to.
//   3. Queue + dismiss: multiple beats in a single scan serialize via
//      tutorialBeatQueue; dismiss advances and releases pause only if
//      owned.
//   4. Card copy coverage: every TutorialBeat case has
//      TutorialBeatCopy content (so the switch is exhaustive and no
//      case renders empty).
//   5. SC4 parity — NON-NEGOTIABLE: a run with tutorialEnabled=false
//      produces identical state after N ticks to a pre-Prompt-18
//      equivalent run. Operationalized as: detector returns empty
//      for every input when tutorialEnabled=false, AND fireBeat is
//      idempotent-no-op (nothing mutates).

final class TutorialBeatSystemTests: XCTestCase {

    // MARK: - 1. Gate + one-shot contract

    func testDetectorReturnsEmptyWhenTutorialDisabled() {
        var s = StartingMall.initialState()
        s.tutorialEnabled = false
        // Force a condition that WOULD trigger several beats:
        // place a cost-bearing artifact, add a closure ledger entry.
        s.artifacts.append(Artifact(
            id: 9999, name: "Neon", type: .neonSign,
            yearCreated: 1982, condition: 0, memoryWeight: 0,
            origin: .playerAction("test"), thoughtTriggers: []
        ))
        s.ledger.append(.closure(ClosureEvent(
            id: UUID(),
            tenantName: "Ghost Co.",
            tenantTier: .standard,
            yearsOpen: 3,
            slotId: 1,
            year: 1985, month: 0
        )))
        let triggered = TutorialBeatDetector.scan(s)
        XCTAssertTrue(triggered.isEmpty,
            "Detector must be a no-op when tutorialEnabled=false (SC4 parity)")
    }

    func testFireBeatIsNoOpWhenTutorialDisabled() {
        let vm = GameViewModel(seed: 1)
        vm.startGame(tutorialEnabled: false)
        let before = vm.state
        vm.fireBeat(.firstPlacement)
        XCTAssertNil(vm.state.activeTutorialBeat,
            "fireBeat must not activate a beat when tutorial is disabled")
        XCTAssertTrue(vm.state.tutorialBeatsSeen.isEmpty,
            "fireBeat must not mutate tutorialBeatsSeen when disabled")
        XCTAssertEqual(vm.state.paused, before.paused,
            "fireBeat must not touch paused when disabled")
    }

    func testBeatFiresOncePerRun() {
        let vm = GameViewModel(seed: 1)
        vm.startGame(tutorialEnabled: true)
        // startGame queues .welcome, which occupies activeTutorialBeat.
        // Dismiss first so a second fire of a different beat can
        // activate cleanly.
        vm.dismissTutorialBeat()
        vm.fireBeat(.firstPlacement)
        XCTAssertEqual(vm.state.activeTutorialBeat, .firstPlacement)
        // Second fire is silently dropped.
        vm.fireBeat(.firstPlacement)
        XCTAssertEqual(vm.state.activeTutorialBeat, .firstPlacement)
        XCTAssertTrue(vm.state.tutorialBeatQueue.isEmpty,
            "Second fire of the same beat must not enqueue")
    }

    // MARK: - 2. Detector triggers

    func testDetectorDetectsFirstPlacement() {
        var s = StartingMall.initialState()
        s.tutorialEnabled = true
        s.artifacts.append(Artifact(
            id: 9999, name: "Neon", type: .neonSign,
            yearCreated: 1982, condition: 0, memoryWeight: 0,
            origin: .playerAction("test"), thoughtTriggers: []
        ))
        XCTAssertTrue(TutorialBeatDetector.scan(s).contains(.firstPlacement))
    }

    func testDetectorDetectsFirstSeal() {
        var s = StartingMall.initialState()
        s.tutorialEnabled = true
        s.artifacts.append(Artifact(
            id: 9999, name: "Sealed Slot", type: .sealedStorefront,
            yearCreated: 1984, condition: 2, memoryWeight: 0,
            origin: .playerAction("seal"), thoughtTriggers: []
        ))
        XCTAssertTrue(TutorialBeatDetector.scan(s).contains(.firstSeal))
    }

    func testDetectorDetectsFirstDisplay() {
        var s = StartingMall.initialState()
        s.tutorialEnabled = true
        s.artifacts.append(Artifact(
            id: 9999, name: "Display", type: .displaySpace,
            yearCreated: 1984, condition: 0, memoryWeight: 0,
            origin: .playerAction("display"), thoughtTriggers: []
        ))
        XCTAssertTrue(TutorialBeatDetector.scan(s).contains(.firstDisplay))
    }

    func testDetectorDetectsFirstHazard() {
        var s = StartingMall.initialState()
        s.tutorialEnabled = true
        var hazardArt = Artifact(
            id: 9999, name: "Neon", type: .neonSign,
            yearCreated: 1982, condition: 4, memoryWeight: 0,
            origin: .playerAction("test"), thoughtTriggers: []
        )
        hazardArt.hazard = true
        s.artifacts.append(hazardArt)
        XCTAssertTrue(TutorialBeatDetector.scan(s).contains(.firstHazard))
    }

    func testDetectorDetectsFirstTenantOffer() {
        var s = StartingMall.initialState()
        s.tutorialEnabled = true
        s.decision = .tenant(TenantOffer(
            name: "Test Tenant", tier: .standard,
            rent: 1000, traffic: 60, threshold: 30, lease: 24,
            pitch: "Test"
        ))
        XCTAssertTrue(TutorialBeatDetector.scan(s).contains(.firstTenantOffer))
    }

    func testDetectorDetectsFirstSpecialtyOfferAlongsideTenantOffer() {
        var s = StartingMall.initialState()
        s.tutorialEnabled = true
        s.decision = .tenant(TenantOffer(
            name: "Podiatrist", tier: .specialty,
            rent: 3200, traffic: 10, threshold: 5, lease: 48,
            pitch: "A podiatrist."
        ))
        let triggered = TutorialBeatDetector.scan(s)
        XCTAssertTrue(triggered.contains(.firstTenantOffer))
        XCTAssertTrue(triggered.contains(.firstSpecialtyOffer))
    }

    func testDetectorDetectsFirstClosure() {
        var s = StartingMall.initialState()
        s.tutorialEnabled = true
        s.ledger.append(.closure(ClosureEvent(
            id: UUID(),
            tenantName: "Mall Shoes",
            tenantTier: .standard,
            yearsOpen: 4,
            slotId: 1,
            year: 1986, month: 3
        )))
        XCTAssertTrue(TutorialBeatDetector.scan(s).contains(.firstClosure))
    }

    func testDetectorDetectsFirstAnchorDeparture() {
        var s = StartingMall.initialState()
        s.tutorialEnabled = true
        s.ledger.append(.anchorDeparture(
            tenantName: "Sears",
            wing: .north,
            trafficDelta: -25,
            coincidentClosureNames: [],
            yearsOpen: 12,
            slotId: 1,
            year: 1990, month: 5
        ))
        XCTAssertTrue(TutorialBeatDetector.scan(s).contains(.firstAnchorDeparture))
    }

    func testDetectorDetectsFirstEnvTransition() {
        var s = StartingMall.initialState()
        s.tutorialEnabled = true
        s.ledger.append(.envTransition(
            from: .thriving, to: .fading,
            year: 1983, month: 2
        ))
        XCTAssertTrue(TutorialBeatDetector.scan(s).contains(.firstEnvTransition))
    }

    func testDetectorDetectsFirstSealedWingSaving() {
        var s = StartingMall.initialState()
        s.tutorialEnabled = true
        s.wingsClosed[.north] = true
        XCTAssertTrue(TutorialBeatDetector.scan(s).contains(.firstSealedWingSaving))
    }

    // MARK: - 3. Queue + dismiss

    func testFireBeatActivatesImmediatelyWhenIdle() {
        let vm = GameViewModel(seed: 1)
        vm.startGame(tutorialEnabled: true)
        // startGame fires .welcome, which claims the pause.
        XCTAssertEqual(vm.state.activeTutorialBeat, .welcome)
        XCTAssertTrue(vm.state.paused)
        XCTAssertTrue(vm.state.tutorialBeatOwnedPause)
    }

    func testSecondBeatQueuesWhenFirstIsActive() {
        let vm = GameViewModel(seed: 1)
        vm.startGame(tutorialEnabled: true)
        // .welcome is active. Fire another; it must queue.
        vm.fireBeat(.firstPlacement)
        XCTAssertEqual(vm.state.activeTutorialBeat, .welcome)
        XCTAssertEqual(vm.state.tutorialBeatQueue, [.firstPlacement])
    }

    func testDismissAdvancesQueue() {
        let vm = GameViewModel(seed: 1)
        vm.startGame(tutorialEnabled: true)
        vm.fireBeat(.firstPlacement)
        vm.dismissTutorialBeat()
        XCTAssertEqual(vm.state.activeTutorialBeat, .firstPlacement,
            "Dismiss must promote the next queued beat")
        XCTAssertTrue(vm.state.tutorialBeatQueue.isEmpty)
    }

    func testDismissReleasesPauseOnlyWhenOwned() {
        let vm = GameViewModel(seed: 1)
        vm.startGame(tutorialEnabled: true)
        XCTAssertTrue(vm.state.tutorialBeatOwnedPause)
        vm.dismissTutorialBeat()
        XCTAssertFalse(vm.state.paused,
            "Dismiss must release pause when beat card owned it")
        XCTAssertFalse(vm.state.tutorialBeatOwnedPause)
    }

    func testDismissHandsOffPauseToTenantOffer() {
        let vm = GameViewModel(seed: 1)
        vm.startGame(tutorialEnabled: true)
        // Simulate a tenant offer arriving while the welcome card is up.
        // Tenant offer's pause was set by something upstream; the beat
        // card must not own this pause.
        vm.state.decision = .tenant(TenantOffer(
            name: "Test", tier: .standard,
            rent: 1000, traffic: 60, threshold: 30, lease: 24,
            pitch: "x"
        ))
        vm.state.tutorialBeatOwnedPause = false  // tenant offer owns it now
        vm.dismissTutorialBeat()
        XCTAssertTrue(vm.state.paused,
            "Dismissing a beat card must not resume if the beat didn't own the pause")
    }

    // MARK: - 4. Card copy coverage

    func testEveryBeatHasCardCopy() {
        for beat in TutorialBeat.allCases {
            let content = TutorialBeatCopy.content(for: beat)
            XCTAssertFalse(content.title.isEmpty,
                "Beat \(beat.rawValue) is missing a title")
            XCTAssertFalse(content.body.isEmpty,
                "Beat \(beat.rawValue) is missing a body")
        }
    }

    // MARK: - 5. SC4 parity

    // Disabled-tutorial parity: a run with tutorialEnabled=false must
    // never touch tutorial state through any tick path. The simplest
    // way to validate this is to tick a number of times and assert the
    // beat-related state fields stay empty.
    func testDisabledRunNeverMutatesBeatState() {
        var s = StartingMall.initialState()
        s.tutorialEnabled = false
        var rng = SeededGenerator(seed: 99)
        for _ in 0..<24 {
            s = TickEngine.tick(s, rng: &rng)
            // autoDismiss so tenant offers / events don't stall the run
            if s.decision != nil {
                s.decision = nil
                s.paused = false
            }
            let triggered = TutorialBeatDetector.scan(s)
            XCTAssertTrue(triggered.isEmpty,
                "Detector must stay silent across a disabled-tutorial run")
        }
        XCTAssertNil(s.activeTutorialBeat)
        XCTAssertTrue(s.tutorialBeatsSeen.isEmpty)
        XCTAssertTrue(s.tutorialBeatQueue.isEmpty)
        XCTAssertFalse(s.tutorialBeatOwnedPause)
    }
}
