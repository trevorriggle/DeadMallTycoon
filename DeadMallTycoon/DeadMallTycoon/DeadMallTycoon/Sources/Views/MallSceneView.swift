import SwiftUI
import SpriteKit

// SwiftUI wrapper around MallScene. One SKView, one scene, lifecycle handled by
// UIViewRepresentable. The scene holds a weak reference to the VM so it can read state
// and push visitor position updates back.
struct MallSceneView: UIViewRepresentable {

    let vm: GameViewModel

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.ignoresSiblingOrder = true
        view.allowsTransparency = false
        let scene = MallScene(size: CGSize(width: GameConstants.worldWidth,
                                            height: GameConstants.worldHeight))
        scene.scaleMode = .aspectFit
        scene.vm = vm
        view.presentScene(scene)
        context.coordinator.scene = scene
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        // Scene owns its own observation — nothing to push here.
        context.coordinator.scene?.vm = vm
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var scene: MallScene?
    }
}
