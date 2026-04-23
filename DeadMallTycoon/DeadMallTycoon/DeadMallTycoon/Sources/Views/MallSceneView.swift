import SwiftUI
import SpriteKit

// SwiftUI wrapper around MallScene. One SKView, one scene, lifecycle handled by
// UIViewRepresentable. The scene holds a weak reference to the VM so it can read
// state and push visitor position updates back.
//
// Phase C additions: SwiftUI card pinning. The scene publishes SKView-local
// positions of the selected store / decoration via closures; MallView captures
// them into @State and positions info cards adjacent to the tapped node.
//
// v9 patch — pinch-zoom + pan. Two UIGestureRecognizers are attached to the
// SKView in makeUIView and forwarded to scene methods on the MallScene
// instance. Gestures are scoped to the SKView, so HUD / toasts / drawer /
// overlay (all SwiftUI above the SKView) remain fully interactive and
// untouched. Single-tap (tap-to-select) continues to flow through the
// scene's `touchesEnded` — the recognizers are non-exclusive
// (cancelsTouchesInView defaults true but with `delaysTouchesEnded = false`
// + simultaneous-recognition, quick taps still reach the scene).
struct MallSceneView: UIViewRepresentable {

    let vm: GameViewModel
    var onStoreAnchorChange: (CGPoint?) -> Void = { _ in }
    var onDecorationAnchorChange: (CGPoint?) -> Void = { _ in }

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.ignoresSiblingOrder = true
        view.allowsTransparency = false
        let scene = MallScene(size: CGSize(width: GameConstants.worldWidth,
                                            height: GameConstants.worldHeight))
        scene.scaleMode = .aspectFit
        scene.vm = vm
        scene.onStoreAnchorChange = onStoreAnchorChange
        scene.onDecorationAnchorChange = onDecorationAnchorChange
        view.presentScene(scene)
        context.coordinator.scene = scene

        // v9 patch — camera gestures.
        // Pinch + pan are attached directly to the SKView so only touches
        // inside the mall field trigger them. The recognizers are set to
        // coexist with each other and to NOT cancel touches in the view —
        // single-tap select (routed by MallScene.touchesEnded) continues
        // to work because a quick tap doesn't trigger either recognizer.
        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:)))
        pinch.delegate = context.coordinator
        pinch.cancelsTouchesInView = false
        view.addGestureRecognizer(pinch)

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.cancelsTouchesInView = false
        // minimumNumberOfTouches stays 1 — one-finger drag pans. Pinch is
        // two-finger, no conflict.
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        // Scene owns its own observation — nothing to push here.
        // Keep the closure captures fresh — SwiftUI hands us new ones on every
        // re-render, and the old captures in the scene become stale otherwise.
        context.coordinator.scene?.vm = vm
        context.coordinator.scene?.onStoreAnchorChange = onStoreAnchorChange
        context.coordinator.scene?.onDecorationAnchorChange = onDecorationAnchorChange
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var scene: MallScene?

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            scene?.handlePinch(g)
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            scene?.handlePan(g)
        }

        // Allow pinch + pan to fire simultaneously. A two-finger gesture is
        // frequently BOTH a pinch (fingers moving apart/together) AND a pan
        // (centroid moving) — the scene should honor both transforms in
        // parallel so zoom-and-drag feels right.
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}
