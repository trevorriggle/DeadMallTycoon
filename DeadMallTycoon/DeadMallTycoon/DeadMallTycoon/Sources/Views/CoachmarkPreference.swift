import SwiftUI

// Coachmark anchor plumbing. Views attach .coachmarkAnchor(.someAnchor) to
// publish their frame in a shared coordinate space; the CoachmarkOverlay
// (Phase 2) reads CoachmarkAnchorKey's merged dictionary and positions its
// arrow + card over the target.
//
// New in the iOS port — v8.html has no coachmark system.
enum CoachmarkSpace {
    static let name = "coachmarkSpace"
}

struct CoachmarkAnchorKey: PreferenceKey {
    static var defaultValue: [CoachmarkAnchor: CGRect] = [:]

    static func reduce(value: inout [CoachmarkAnchor: CGRect],
                       nextValue: () -> [CoachmarkAnchor: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    // Publish this view's frame, converted to CoachmarkSpace, under `anchor`.
    // Safe to attach on anything with a bounded layout — a GeometryReader inside
    // a clear background does the measurement without affecting layout.
    func coachmarkAnchor(_ anchor: CoachmarkAnchor) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: CoachmarkAnchorKey.self,
                    value: [anchor: geo.frame(in: .named(CoachmarkSpace.name))]
                )
            }
        )
    }
}
