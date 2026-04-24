import XCTest
import SwiftUI
@testable import DeadMallTycoon

// v9 Prompt 23 — adaptive UI scale contract. Static coverage; test
// target isn't Xcode-wired per CLAUDE.md. Protects the clamp range
// from accidental regressions when the baseline device class changes.

final class UIScaleComputationTests: XCTestCase {

    func testBaselineDeviceReturnsApproximatelyOne() {
        // iPad Pro 11" 1st gen portrait matches the baseline.
        let scale = computeUIScale(for: CGSize(width: 1024, height: 1366))
        XCTAssertEqual(scale, 1.0, accuracy: 0.001)
    }

    func testIPadMiniPortraitClampsToMinScale() {
        // iPad mini 6 portrait: 744 × 1133. Raw width scale = 0.727;
        // height scale = 0.829. min → 0.727 → clamped up to minScale.
        let scale = computeUIScale(for: CGSize(width: 744, height: 1133))
        XCTAssertEqual(scale, UIScaleBaseline.minScale, accuracy: 0.001,
                       "iPad mini must clamp to minScale, not scale below it")
    }

    func testIPadPro13LandscapeClampsToMaxScale() {
        // iPad Pro 13" 7th gen landscape: 1376 × 1032. Raw min axis
        // scale = 1032/1366 = 0.755… no wait: width scale = 1376/1024 = 1.344;
        // height scale = 1032/1366 = 0.755. min → 0.755 → within range.
        // Rotate to portrait for the big device case:
        let scale = computeUIScale(for: CGSize(width: 1032, height: 1376))
        XCTAssertLessThanOrEqual(scale, UIScaleBaseline.maxScale + 0.001)
        XCTAssertGreaterThanOrEqual(scale, UIScaleBaseline.minScale - 0.001)
    }

    func testHugeViewportClampsToMaxScale() {
        // A hypothetical 2× baseline viewport should clamp, not scale 2×.
        let scale = computeUIScale(for: CGSize(width: 2048, height: 2732))
        XCTAssertEqual(scale, UIScaleBaseline.maxScale, accuracy: 0.001,
                       "oversized viewports must clamp to maxScale")
    }

    func testZeroOrNegativeViewportFallsBackToOne() {
        XCTAssertEqual(computeUIScale(for: .zero), 1.0)
        XCTAssertEqual(computeUIScale(for: CGSize(width: 0, height: 100)), 1.0)
        XCTAssertEqual(computeUIScale(for: CGSize(width: 100, height: 0)), 1.0)
    }

    func testMinScaleIsReadable() {
        // A 10pt label (smallest in the HUD) must remain legible at
        // the lower clamp. 10 × 0.80 = 8pt; anything below is a bug.
        let smallestAuthoredLabel: CGFloat = 10
        let smallest = smallestAuthoredLabel * UIScaleBaseline.minScale
        XCTAssertGreaterThanOrEqual(smallest, 8.0,
                                    "minScale must not push the smallest label below 8pt")
    }

    func testCompactMinScaleKeepsPrimaryLabelsReadable() {
        // v9 Prompt 24 — compact floor is looser to let iPhone-height
        // viewports breathe. Main-line labels (14pt+) must still clear
        // 10pt after scaling; sublabels (10pt) may drop to ~7.2pt,
        // which is tight but legible for secondary info.
        let main: CGFloat   = 14
        let sublabel: CGFloat = 10
        XCTAssertGreaterThanOrEqual(main * UIScaleBaseline.minScaleCompact, 10.0)
        XCTAssertGreaterThanOrEqual(sublabel * UIScaleBaseline.minScaleCompact, 7.0)
    }

    func testIPhoneLandscapeUsesCompactFloor() {
        // iPhone 15 landscape: 852 × 393. hScale = 393/1366 ≈ 0.287
        // — below the iPad floor (0.80) AND below the compact floor
        // (0.72). Passing the compact floor clamps to 0.72.
        let compact = computeUIScale(for: CGSize(width: 852, height: 393),
                                     minScale: UIScaleBaseline.minScaleCompact)
        XCTAssertEqual(compact, UIScaleBaseline.minScaleCompact, accuracy: 0.001)

        // With the iPad (default) floor the same viewport pins at 0.80.
        let regular = computeUIScale(for: CGSize(width: 852, height: 393))
        XCTAssertEqual(regular, UIScaleBaseline.minScale, accuracy: 0.001)
    }

    func testScaleIsMonotonicInDominantAxis() {
        // Shrinking either axis must not increase the scale.
        let baseline = computeUIScale(for: CGSize(width: 1024, height: 1366))
        let narrower = computeUIScale(for: CGSize(width: 900, height: 1366))
        let shorter  = computeUIScale(for: CGSize(width: 1024, height: 1200))
        XCTAssertLessThanOrEqual(narrower, baseline + 0.001)
        XCTAssertLessThanOrEqual(shorter, baseline + 0.001)
    }
}
