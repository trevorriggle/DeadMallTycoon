import XCTest
@testable import DeadMallTycoon

// v9 Prompt 11 coverage. AVAudioPlayer-level playback / crossfade / delegate
// behavior is integration-tested manually on device — it depends on real
// audio assets loaded from Bundle.main and the audio session being live.
//
// What IS unit-testable is the pure track-picker function that drives the
// non-repeat contract: `MusicService.pickTrack(from:avoiding:)`. The rule
// is strict non-repeat within a state session, with fallback to any track
// when the pool is a single element that matches the avoid-target.

final class MusicServiceTrackPickerTests: XCTestCase {

    private let a = URL(fileURLWithPath: "/tmp/a.mp3")
    private let b = URL(fileURLWithPath: "/tmp/b.mp3")
    private let c = URL(fileURLWithPath: "/tmp/c.mp3")

    func testEmptyPoolReturnsNil() {
        XCTAssertNil(MusicService.pickTrack(from: [], avoiding: nil))
        XCTAssertNil(MusicService.pickTrack(from: [], avoiding: a))
    }

    func testSingleTrackPoolAlwaysReturnsThatTrack() {
        XCTAssertEqual(MusicService.pickTrack(from: [a], avoiding: nil), a)
        // Avoid-target is the only track. Fallback permits it.
        XCTAssertEqual(MusicService.pickTrack(from: [a], avoiding: a), a)
    }

    func testNonRepeatStrictWhenAlternativesExist() {
        // Over 50 trials, pickTrack should NEVER return `a` when we're
        // avoiding `a` (strict non-repeat).
        for _ in 0..<50 {
            let picked = MusicService.pickTrack(from: [a, b], avoiding: a)
            XCTAssertEqual(picked, b,
                           "strict non-repeat: avoiding a in [a, b] must pick b every time")
        }
    }

    func testNonRepeatAcrossLargerPool() {
        for _ in 0..<100 {
            let picked = MusicService.pickTrack(from: [a, b, c], avoiding: b)
            XCTAssertNotNil(picked)
            XCTAssertNotEqual(picked, b,
                              "strict non-repeat: avoiding b must pick a or c")
        }
    }

    func testNilAvoidingAllowsAnyTrack() {
        var seenA = false, seenB = false
        for _ in 0..<50 {
            switch MusicService.pickTrack(from: [a, b], avoiding: nil) {
            case .some(let url) where url == a: seenA = true
            case .some(let url) where url == b: seenB = true
            default: break
            }
            if seenA && seenB { break }
        }
        XCTAssertTrue(seenA && seenB,
                      "with nil avoid-target, both tracks should be reachable")
    }

    func testAvoidTargetNotInPoolTreatedAsIfNil() {
        let outsider = URL(fileURLWithPath: "/tmp/other.mp3")
        // `outsider` isn't in the pool; pickTrack should pick any from [a, b].
        for _ in 0..<50 {
            let picked = MusicService.pickTrack(from: [a, b], avoiding: outsider)
            XCTAssertNotNil(picked)
            XCTAssertTrue(picked == a || picked == b)
        }
    }
}
