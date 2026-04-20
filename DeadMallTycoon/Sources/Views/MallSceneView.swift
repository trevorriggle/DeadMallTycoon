import SwiftUI
import SpriteKit

// SwiftUI wrapper around MallScene. One SKView, one scene, lifecycle handled by
// UIViewRepresentable. The scene holds a weak reference to the VM so it can read
// state and push visitor position updates back.
//
// Phase C additions: SwiftUI card pinning. The scene publishes SKView-local
// positions of the selected store / decoration via closures; MallView captures
// them into @State and positions info cards adjacent to the tapped node.
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

    final class Coordinator {
        weak var scene: MallScene?
    }
}
