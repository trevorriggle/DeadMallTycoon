import SwiftUI

// v9 Prompt 23 — adaptive UI scale for varying iPad screen sizes.
//
// Most HUD and modal-card sizes in this codebase are hardcoded pt
// values (26pt cash font, 520pt card max-widths, 140pt threat bar, etc.)
// originally tuned against one iPad class. That means on iPad mini the
// HUD eats too much vertical space, the threat meter is proportionally
// too wide, and modal cards leave a lot of dead margin; on iPad Pro 13"
// everything looks slightly undersized.
//
// This file adds a single scale factor injected from the app root via
// GeometryReader and consumed by `.scaledFont`, `.scaledSize`, and
// `.scaledFrame` modifiers at call sites. The scale is clamped so the
// UI stays legible on small devices without ballooning on large ones.
//
// Scope: HUD + full-screen modal cards. Drawer/sheet detents already
// adapt. Size-class-aware reflow (different layouts on compact vs
// regular) is a separate, larger pass; this is the quick proportional
// pass that unblocks playtesting across device classes.

// MARK: - Environment injection

// Baseline the scale factor is computed against. iPad Pro 11" (1st gen)
// portrait width × iPad Pro 11" 1st-gen portrait height. Chosen because
// most of the hardcoded pts were authored against roughly this surface;
// any device whose width/height is smaller in that dimension scales
// down, any device larger scales up.
enum UIScaleBaseline {
    static let width:  CGFloat = 1024
    static let height: CGFloat = 1366
    // Range chosen empirically: below 0.80 the 10pt monospaced labels
    // become unreadable; above 1.12 the HUD starts eating too much
    // vertical space on iPad Pro 13".
    static let minScale: CGFloat = 0.80
    static let maxScale: CGFloat = 1.12
    // v9 Prompt 24 — on compact-width (iPhone landscape) the vertical
    // axis is short enough (~375–430pt vs 1366 baseline) that the
    // dominant-axis clamp pins at the floor. Dropping the floor to
    // 0.72 on compact buys back ~10% of vertical HUD budget at the
    // cost of 10pt sublabels (MONTH, memory tag) rendering at 7.2pt —
    // legible but tight. Main-line labels (cash 26pt → 18.7pt, date
    // 18pt → 12.96pt) stay comfortably readable.
    static let minScaleCompact: CGFloat = 0.72
}

// Pure function so both the GeometryReader root AND tests can compute
// the scale identically. Caller passes the actual viewport; callee
// returns the clamped scale.
//
// v9 Prompt 24 — `minScale` defaults to the iPad floor but callers that
// know they're on compact-width can pass UIScaleBaseline.minScaleCompact.
// InjectUIScale picks the right floor via @Environment(\.horizontalSizeClass).
func computeUIScale(for viewport: CGSize,
                    baseline: CGSize = CGSize(width: UIScaleBaseline.width,
                                              height: UIScaleBaseline.height),
                    minScale: CGFloat = UIScaleBaseline.minScale)
-> CGFloat {
    // Scale to the DOMINANT axis — on an iPad in landscape, height is
    // the binding constraint (short axis); in portrait, width is. Taking
    // the minimum keeps the HUD from ever getting clipped off-screen.
    guard viewport.width > 0, viewport.height > 0 else { return 1.0 }
    let wScale = viewport.width / baseline.width
    let hScale = viewport.height / baseline.height
    let raw = min(wScale, hScale)
    return max(minScale, min(UIScaleBaseline.maxScale, raw))
}

private struct UIScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    // Proportional UI scale factor. 1.0 means the surface is being
    // rendered at its authored pt values; <1 scales down (smaller
    // iPads), >1 scales up (iPad Pro 13"). Clamped to the range in
    // UIScaleBaseline. Root injector lives in ContentView.
    var uiScale: CGFloat {
        get { self[UIScaleKey.self] }
        set { self[UIScaleKey.self] = newValue }
    }
}

// MARK: - Call-site helpers

extension View {
    // Font whose point size scales with the environment's uiScale.
    // Mirrors `.font(.system(size:weight:design:))` — same call shape,
    // same parameters, just proportional. Call sites that don't read
    // the environment remain at 1.0 by default.
    func scaledFont(size: CGFloat,
                    weight: Font.Weight = .regular,
                    design: Font.Design = .default) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, design: design))
    }

    // Frame whose width/height scale with uiScale. Pass nil to leave
    // an axis unconstrained, exactly like SwiftUI's native .frame.
    func scaledFrame(width: CGFloat? = nil,
                     height: CGFloat? = nil,
                     alignment: Alignment = .center) -> some View {
        modifier(ScaledFrameModifier(width: width, height: height,
                                      alignment: alignment))
    }

    // Frame whose maxWidth/maxHeight scale with uiScale. Used where a
    // card body should cap at e.g. 520pt on the baseline device but
    // widen slightly on iPad Pro 13" / narrow on iPad mini.
    func scaledFrame(maxWidth: CGFloat? = nil,
                     maxHeight: CGFloat? = nil,
                     alignment: Alignment = .center) -> some View {
        modifier(ScaledMaxFrameModifier(maxWidth: maxWidth,
                                         maxHeight: maxHeight,
                                         alignment: alignment))
    }

    // v9 Prompt 24 — modal-card max-width that drops entirely on
    // horizontalSizeClass == .compact. On iPad this scales the passed
    // max-width by uiScale like `scaledFrame(maxWidth:)`; on iPhone
    // landscape the cap is removed so the card fills the viewport
    // horizontally (subtracting the caller's own .padding).
    func modalCardMaxWidth(_ width: CGFloat) -> some View {
        modifier(ModalCardMaxWidthModifier(baseline: width))
    }

    // Padding whose edge insets scale with uiScale. Mirrors
    // `.padding(_:,_:)` with a single-value form; use multiple calls
    // for asymmetric insets.
    func scaledPadding(_ edges: Edge.Set = .all,
                       _ length: CGFloat) -> some View {
        modifier(ScaledPaddingModifier(edges: edges, length: length))
    }
}

// MARK: - Modifiers

private struct ScaledFontModifier: ViewModifier {
    @Environment(\.uiScale) private var uiScale
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: size * uiScale, weight: weight, design: design))
    }
}

private struct ScaledFrameModifier: ViewModifier {
    @Environment(\.uiScale) private var uiScale
    let width:  CGFloat?
    let height: CGFloat?
    let alignment: Alignment

    func body(content: Content) -> some View {
        content.frame(
            width:  width.map  { $0 * uiScale },
            height: height.map { $0 * uiScale },
            alignment: alignment
        )
    }
}

private struct ScaledMaxFrameModifier: ViewModifier {
    @Environment(\.uiScale) private var uiScale
    let maxWidth:  CGFloat?
    let maxHeight: CGFloat?
    let alignment: Alignment

    func body(content: Content) -> some View {
        content.frame(
            maxWidth:  maxWidth.map  { $0 * uiScale },
            maxHeight: maxHeight.map { $0 * uiScale },
            alignment: alignment
        )
    }
}

private struct ModalCardMaxWidthModifier: ViewModifier {
    @Environment(\.uiScale) private var uiScale
    @Environment(\.horizontalSizeClass) private var hSize
    let baseline: CGFloat

    func body(content: Content) -> some View {
        // On compact (iPhone landscape), let the card fill — the
        // viewport's already narrow, further capping wastes space.
        // On regular (iPad), cap at the baseline × uiScale.
        if hSize == .compact {
            content.frame(maxWidth: .infinity)
        } else {
            content.frame(maxWidth: baseline * uiScale)
        }
    }
}

private struct ScaledPaddingModifier: ViewModifier {
    @Environment(\.uiScale) private var uiScale
    let edges: Edge.Set
    let length: CGFloat

    func body(content: Content) -> some View {
        content.padding(edges, length * uiScale)
    }
}

// MARK: - Root injector

// Wrap a view's content so every child resolves `@Environment(\.uiScale)`
// to the value computed from the current viewport. Place near the root
// of a full-screen surface (e.g. ContentView); nested InjectUIScale calls
// are harmless — the innermost wins.
//
// v9 Prompt 24 — picks the floor based on `horizontalSizeClass`. Compact
// (iPhone landscape) gets UIScaleBaseline.minScaleCompact so the HUD
// doesn't eat disproportionate vertical space on short viewports.
struct InjectUIScale<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var hSize
    let content: Content

    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let floor: CGFloat = (hSize == .compact)
                ? UIScaleBaseline.minScaleCompact
                : UIScaleBaseline.minScale
            content
                .environment(\.uiScale,
                             computeUIScale(for: geo.size, minScale: floor))
        }
    }
}
