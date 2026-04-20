import SpriteKit
import Observation

// The mall corridor renderer. Reads GameViewModel; mutates only via explicit player-action
// calls (selectVisitor, placeDecoration, etc.).
// Visitors are scene-local presentation state — owned here, never in GameState — so
// their 60fps position updates don't churn the Observation loop. Store and decoration
// lifecycle is diff-reconciled against GameState whenever state changes.
// Visitor motion logic is a direct port of v8 updateVisitorPositions().
final class MallScene: SKScene {

    // MARK: Public

    weak var vm: GameViewModel?

    // Phase C — SwiftUI info-card pinning. MallView sets these closures and
    // receives SKView-local anchor points (top-left coord system) whenever the
    // selected store/decoration moves, the view resizes, or selection changes.
    // Cards use these to position themselves adjacent to the tapped node.
    var onStoreAnchorChange: ((CGPoint?) -> Void)?
    var onDecorationAnchorChange: ((CGPoint?) -> Void)?

    // MARK: Private

    private let worldNode = SKNode()     // background + corridor + nodes (y-down coord system)
    private let corridorNode = SKNode()
    private let storesLayer = SKNode()
    private let decorationsLayer = SKNode()
    private let visitorsLayer = SKNode()
    private let overlayLayer = SKNode()

    private var storeNodes: [Int: StoreNode] = [:]
    private var decorationNodes: [Int: DecorationNode] = [:]
    private var visitorNodes: [UUID: VisitorNode] = [:]

    // Scene-local visitor presentation state — not in GameState, not observed.
    // Keeps 60fps position writes out of the Observation loop.
    private var visitors: [Visitor] = []
    private var visitorRNG = SeededGenerator(seed: UInt64.random(in: 1..<UInt64.max))

    // Detect restart transitions (gameover → started again) so we can flush scene-local state.
    private var lastStartedFlag: Bool = false
    private var lastGameoverFlag: Bool = false

    // Phase C — threat band transition tracking + published anchor memoization.
    private var lastThreatBand: ThreatBand = .stable
    private var lastStoreAnchor: CGPoint?
    private var lastDecorationAnchor: CGPoint?

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = Palette.backgroundNight
        anchorPoint = CGPoint(x: 0, y: 0)
        // MUST stay aspectFit — the scene is authored at 1200×520 (CSS world coords)
        // and csToScene() flips y relative to size.height. `.resizeFill` would stretch
        // size to the SKView bounds, making csToScene map the south wing off-screen
        // whenever the SKView ends up shorter than 520pt (which is the common case
        // now that MallView fits to world aspect). MallSceneView already sets this on
        // present; repeating here so a future refactor can't silently regress.
        scaleMode = .aspectFit

        buildStaticBackground()
        addChild(worldNode)
        worldNode.addChild(corridorNode)

        // Layer order: corridor floor, decorations, stores, visitors, overlays
        worldNode.addChild(decorationsLayer)
        worldNode.addChild(storesLayer)
        worldNode.addChild(visitorsLayer)
        worldNode.addChild(overlayLayer)

        // Register observation: reconcile whenever any observable state property is read
        // the next time it changes. We continually re-register after each change so
        // reconciliation keeps happening over time.
        observeAndReconcile()

        // v8: initVisitors() — seed 12 visitors spread across the corridor in wandering state.
        seedInitialVisitors()
    }

    // v8: initVisitors() — 12 wandering visitors at random corridor positions.
    // Waits for the game to have started (stores populated) before seeding so personalities
    // pull from the correct mall-state weights instead of the degenerate empty-mall → dead case.
    private var didSeedVisitors = false
    private func seedInitialVisitors() {
        guard let vm, vm.state.started, !didSeedVisitors else { return }
        didSeedVisitors = true
        let s = vm.state
        for _ in 0..<12 {
            var v = VisitorFactory.spawn(state: s, rng: &visitorRNG)
            v.x = 50 + Double.random(in: 0..<1100, using: &visitorRNG)
            v.y = 220 + Double.random(in: 0..<60, using: &visitorRNG)
            v.state = .wandering
            visitors.append(v)
        }
    }

    // MARK: Static background (floor / ceiling / walls / sealed wings)

    private func buildStaticBackground() {
        // CSS coord system: (0,0) top-left, y increases down.
        // SpriteKit: (0,0) bottom-left. Convert via sceneY().

        // ceiling-bg: top 0..130
        addTiled(texture: TextureFactory.ceilingTile(),
                 rectCSS: CGRect(x: 0, y: 0,
                                  width: GameConstants.worldWidth,
                                  height: GameConstants.corridorTop))

        // floor-bg (below corridor): y 390..520
        addTiled(texture: TextureFactory.ceilingTile(),
                 rectCSS: CGRect(x: 0, y: GameConstants.corridorBottom,
                                  width: GameConstants.worldWidth,
                                  height: GameConstants.worldHeight - GameConstants.corridorBottom))

        // corridor: y 130..390
        addTiled(texture: TextureFactory.floorTile(),
                 rectCSS: CGRect(x: 0, y: GameConstants.corridorTop,
                                  width: GameConstants.worldWidth,
                                  height: GameConstants.corridorBottom - GameConstants.corridorTop))

        // walls: thin horizontal strips at y=128 and y=388
        addWall(atCSSy: 128)
        addWall(atCSSy: 388)
    }

    private func addTiled(texture: SKTexture, rectCSS: CGRect) {
        // SKSpriteNode with texture set to tile by using SKAction? No — SKTexture does not
        // auto-tile. Instead, replicate the tile by setting the sprite to the tile's size
        // and stepping across the rect. Keep tile count manageable.
        let tileSize = texture.size()
        var y: CGFloat = 0
        while y < rectCSS.height {
            var x: CGFloat = 0
            while x < rectCSS.width {
                let sprite = SKSpriteNode(texture: texture)
                sprite.size = tileSize
                sprite.position = csToScene(x: rectCSS.origin.x + x + tileSize.width / 2,
                                            y: rectCSS.origin.y + y + tileSize.height / 2)
                sprite.zPosition = -100
                corridorNode.addChild(sprite)
                x += tileSize.width
            }
            y += tileSize.height
        }
    }

    private func addWall(atCSSy y: CGFloat) {
        let wall = SKSpriteNode(color: Palette.wall,
                                 size: CGSize(width: GameConstants.worldWidth, height: 3))
        wall.position = csToScene(x: GameConstants.worldWidth / 2, y: y)
        wall.zPosition = -50
        corridorNode.addChild(wall)
    }

    // MARK: Observation

    private func observeAndReconcile() {
        guard let vm else { return }
        withObservationTracking {
            // Touch everything we care about so changes trigger re-registration.
            _ = vm.state.stores
            _ = vm.state.decorations
            _ = vm.state.wingsClosed
            _ = vm.state.wingsDowngraded
            _ = vm.state.selectedVisitorId
            _ = vm.state.selectedStoreId
            _ = vm.state.started
            _ = vm.state.gameover
            handleLifecycleTransition(vm.state)
            reconcile(state: vm.state)
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.observeAndReconcile()
            }
        }
    }

    // Flush scene-local visitor state on restart so an old run doesn't bleed into a new one.
    private func handleLifecycleTransition(_ state: GameState) {
        defer {
            lastStartedFlag = state.started
            lastGameoverFlag = state.gameover
        }
        let isRestart = (lastGameoverFlag && !state.gameover && state.started)
                     || (!lastStartedFlag && state.started && !visitors.isEmpty)
        if isRestart {
            for node in visitorNodes.values { node.removeFromParent() }
            visitorNodes.removeAll()
            visitors.removeAll()
            didSeedVisitors = false
        }
    }

    // MARK: Reconciliation — diff nodes against state

    private func reconcile(state: GameState) {
        reconcileStores(state)
        reconcileDecorations(state)
        reconcileSealedWings(state)
        reconcileWingTint(state)        // Phase C — red tint on wings about to fail
        reconcileThreatFlash(state)     // Phase C — vignette flash when entering critical
        reconcileDim(state)
        publishSelectionAnchors(state)  // Phase C — SwiftUI card pinning
        // visitor selection highlight (visitors themselves are scene-local)
        for (id, node) in visitorNodes {
            node.markSelected(state.selectedVisitorId == id)
        }
    }

    // Phase C — subtle red tint on a wing background when any store in the wing
    // is `closing`. Surfaces the "wing about to fail" signal in-scene so the
    // player doesn't need the old Watch List panel to spot it.
    private func reconcileWingTint(_ state: GameState) {
        overlayLayer.children
            .filter { $0.name?.hasPrefix("wingTint:") == true }
            .forEach { $0.removeFromParent() }

        for wing in Wing.allCases {
            guard !Mall.isWingClosed(wing, in: state) else { continue }
            let closingInWing = state.stores.contains { $0.wing == wing && $0.closing }
            guard closingInWing else { continue }

            let (cssY, height): (CGFloat, CGFloat) = {
                if wing == .north {
                    return (0, GameConstants.corridorTop)
                }
                return (GameConstants.corridorBottom,
                        GameConstants.worldHeight - GameConstants.corridorBottom)
            }()
            let tint = SKSpriteNode(
                color: SKColor(red: 0.89, green: 0.29, blue: 0.29, alpha: 0.12),
                size: CGSize(width: GameConstants.worldWidth, height: height)
            )
            tint.position = csToScene(x: GameConstants.worldWidth / 2, y: cssY + height / 2)
            tint.zPosition = 45
            tint.name = "wingTint:\(wing.rawValue)"
            overlayLayer.addChild(tint)
        }
    }

    // Phase C — red vignette flash when the threat meter first crosses into
    // the Critical band. One-shot; the flash removes itself after fading out.
    private func reconcileThreatFlash(_ state: GameState) {
        let band = Threat.band(state.threatMeter)
        if band == .critical && lastThreatBand != .critical {
            triggerCriticalVignetteFlash()
        }
        lastThreatBand = band
    }

    private func triggerCriticalVignetteFlash() {
        let border = SKShapeNode(
            rect: CGRect(x: 0, y: 0,
                         width: GameConstants.worldWidth,
                         height: GameConstants.worldHeight)
        )
        border.strokeColor = SKColor(red: 0.89, green: 0.29, blue: 0.29, alpha: 1.0)
        border.lineWidth = 60
        border.glowWidth = 30
        border.fillColor = .clear
        border.alpha = 0
        border.zPosition = 150
        border.name = "criticalFlash"
        overlayLayer.addChild(border)

        border.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 0.18),
            SKAction.fadeAlpha(to: 0.0, duration: 0.7),
            SKAction.removeFromParent(),
        ]))
    }

    // Phase C — publish the SKView-local (top-left) position of the selected
    // store / decoration so SwiftUI can pin info cards next to the tapped node.
    // Called from reconcile (selection changes) and update(_:) (view resize /
    // rotation tracked frame-by-frame). Memoizes to avoid spamming @State.
    private func publishSelectionAnchors(_ state: GameState) {
        let storePt = anchorInView(for: state.selectedStoreId.flatMap { storeNodes[$0] })
        if storePt != lastStoreAnchor {
            lastStoreAnchor = storePt
            onStoreAnchorChange?(storePt)
        }
        let decPt = anchorInView(for: state.selectedDecorationId.flatMap { decorationNodes[$0] })
        if decPt != lastDecorationAnchor {
            lastDecorationAnchor = decPt
            onDecorationAnchorChange?(decPt)
        }
    }

    private func anchorInView(for node: SKNode?) -> CGPoint? {
        guard let node, let view else { return nil }
        return view.convert(node.position, from: self)
    }

    private func reconcileStores(_ state: GameState) {
        let seen = Set(state.stores.map { $0.id })
        // Remove orphans (shouldn't happen — 20 slots are stable)
        for id in storeNodes.keys where !seen.contains(id) {
            storeNodes[id]?.removeFromParent(); storeNodes.removeValue(forKey: id)
        }
        // Upsert
        for s in state.stores {
            let hidden = Mall.isWingClosed(s.wing, in: state)
            if let node = storeNodes[s.id] {
                node.isHidden = hidden
                node.apply(store: s)
            } else if !hidden {
                let node = StoreNode(store: s)
                node.position = csToScene(x: s.position.x + s.position.w / 2,
                                          y: s.position.y + s.position.h / 2)
                node.zPosition = 10
                storesLayer.addChild(node)
                storeNodes[s.id] = node
            }
        }
    }

    private func reconcileDecorations(_ state: GameState) {
        let seen = Set(state.decorations.map { $0.id })
        for id in decorationNodes.keys where !seen.contains(id) {
            decorationNodes[id]?.removeFromParent()
            decorationNodes.removeValue(forKey: id)
        }
        for d in state.decorations {
            let size = DecorationTypes.type(d.kind).size
            let scenePos = csToScene(x: d.x + size.width / 2, y: d.y + size.height / 2)
            if let node = decorationNodes[d.id] {
                node.position = scenePos
                node.apply(decoration: d)
            } else {
                let node = DecorationNode(decoration: d)
                node.position = scenePos
                node.zPosition = 5
                decorationsLayer.addChild(node)
                decorationNodes[d.id] = node
            }
        }
    }

    private func reconcileSealedWings(_ state: GameState) {
        // Remove any existing overlays and re-add.
        overlayLayer.children
            .filter { $0.name?.hasPrefix("sealed:") == true }
            .forEach { $0.removeFromParent() }

        func overlay(for wing: Wing, cssY: CGFloat, height: CGFloat) {
            let width = GameConstants.worldWidth
            let tex = TextureFactory.wingSealedTile()
            // cover the wing band via repeated tiles inside a container that's masked to the rect
            let container = SKCropNode()
            container.name = "sealed:\(wing.rawValue)"
            let mask = SKSpriteNode(color: .white, size: CGSize(width: width, height: height))
            mask.position = csToScene(x: width / 2, y: cssY + height / 2)
            container.maskNode = mask
            let tileSize = tex.size()
            var y: CGFloat = 0
            while y < height {
                var x: CGFloat = 0
                while x < width {
                    let s = SKSpriteNode(texture: tex)
                    s.size = tileSize
                    s.position = csToScene(x: x + tileSize.width / 2,
                                           y: cssY + y + tileSize.height / 2)
                    container.addChild(s)
                    x += tileSize.width
                }
                y += tileSize.height
            }
            let label = SKLabelNode(fontNamed: "Courier-Bold")
            label.fontColor = Palette.wingSealedLabel
            label.fontSize = 14
            label.text = "\(wing == .north ? "NORTH" : "SOUTH") WING SEALED"
            label.verticalAlignmentMode = .center
            label.position = csToScene(x: width / 2, y: cssY + height / 2)
            container.addChild(label)
            container.zPosition = 50
            overlayLayer.addChild(container)
        }

        if Mall.isWingClosed(.north, in: state) {
            overlay(for: .north, cssY: 0, height: GameConstants.corridorTop)
        }
        if Mall.isWingClosed(.south, in: state) {
            overlay(for: .south, cssY: GameConstants.corridorBottom,
                    height: GameConstants.worldHeight - GameConstants.corridorBottom)
        }
    }

    // v8 filter: brightness+saturation per abandonment level on the corridor
    private func reconcileDim(_ state: GameState) {
        let level = Mall.abandonmentLevel(state)
        let (brightness, saturation) = Palette.dimLevels[min(level, Palette.dimLevels.count - 1)]
        // Apply to the corridor floor layer via color tint (cheap approximation of CSS filter).
        // A full CIFilter brightness/saturation would require wrapping in SKEffectNode, which
        // we can adopt later if needed for fidelity.
        let dim = CGFloat(1.0 - brightness) * 0.7
        let tint = UIColor.black.withAlphaComponent(dim)
        corridorNode.children.forEach { child in
            guard let sprite = child as? SKSpriteNode else { return }
            sprite.color = tint
            sprite.colorBlendFactor = CGFloat(1.0 - saturation) * 0.5 + dim
        }
    }

    // MARK: Visitor motion — port of v8 updateVisitorPositions()
    // Scene-local: writes to `visitors` and `visitorNodes`, never to vm.state.

    override func update(_ currentTime: TimeInterval) {
        guard let vm else { return }
        let s = vm.state
        // Seed visitors lazily once the game has actually started and populated stores.
        seedInitialVisitors()

        // Phase C — re-publish SwiftUI card anchors every frame while a selection
        // exists. Cheap: the anchor is memoized and the callback only fires on a
        // real coordinate change (e.g. orientation change, SKView resize).
        if s.selectedStoreId != nil || s.selectedDecorationId != nil {
            publishSelectionAnchors(s)
        }

        // Seed this frame once on VM startup; don't reseed every frame or picks correlate.
        // The `visitorRNG` persists across frames.

        // Advance each visitor toward its target. Same numerical behavior as v8:
        // - if at target and targetType=="store", dwellTimer counts up; after 180 frames
        //   either start leaving (15% chance) or re-pick a target.
        // - if at target and targetType=="wander", pick a new target.
        // - visitors in state=leaving keep their vx/vy until off-screen, then despawn.
        var toRemove: [UUID] = []
        for i in visitors.indices {
            var v = visitors[i]
            guard let target = v.target else {
                VisitorFactory.pickTarget(for: &v, in: s, rng: &visitorRNG)
                visitors[i] = v
                continue
            }
            let dx = target.x - v.x
            let dy = target.y - v.y
            let dist = (dx*dx + dy*dy).squareRoot()

            if v.state == .leaving {
                if v.x < -30 || v.x > 1220 {
                    toRemove.append(v.id)
                } else {
                    v.x += v.vx
                    v.y += v.vy
                }
            } else if dist < 3 {
                if v.targetType == "store" {
                    v.dwellTimer += 1
                    if v.dwellTimer > 180 {
                        v.dwellTimer = 0
                        if visitorRNG.chance(0.15) {
                            v.state = .leaving
                            v.vx = v.x < 600 ? -1.2 : 1.2
                            v.vy = 0
                        } else {
                            VisitorFactory.pickTarget(for: &v, in: s, rng: &visitorRNG)
                        }
                    }
                } else {
                    VisitorFactory.pickTarget(for: &v, in: s, rng: &visitorRNG)
                }
            } else {
                v.x += (dx / dist) * v.speed
                v.y += (dy / dist) * v.speed
            }
            visitors[i] = v
        }

        // Despawn off-screen leavers.
        for id in toRemove {
            visitorNodes[id]?.removeFromParent()
            visitorNodes.removeValue(forKey: id)
        }
        visitors.removeAll { toRemove.contains($0.id) }

        // Spawn toward target count — v8 throttled at 2% chance per frame.
        let targetCount = VisitorFactory.targetVisitorCount(s)
        if visitors.count < targetCount && visitorRNG.chance(0.02) {
            let v = VisitorFactory.spawn(state: s, rng: &visitorRNG)
            visitors.append(v)
        }

        // Ensure every visitor has a node, update positions.
        for v in visitors {
            if visitorNodes[v.id] == nil {
                let node = VisitorNode(visitor: v)
                node.position = csToScene(x: v.x, y: v.y)
                node.zPosition = 20
                visitorsLayer.addChild(node)
                visitorNodes[v.id] = node
                node.markSelected(s.selectedVisitorId == v.id)
            } else {
                visitorNodes[v.id]?.position = csToScene(x: v.x, y: v.y)
            }
        }
    }

    // MARK: Touch routing — tap visitors / stores / decorations / place decoration

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let vm else { return }
        let p = touch.location(in: self)
        let hits = nodes(at: p)
        // Prefer visitor → store → decoration order (topmost visual priority)
        if let visitorNode = hits.first(where: { $0 is VisitorNode }) as? VisitorNode,
           let visitor = visitors.first(where: { $0.id == visitorNode.visitorId }) {
            vm.selectVisitor(visitor)
            showThoughtAboveVisitor(id: visitor.id)
            return
        }
        if let storeNode = hits.first(where: { $0 is StoreNode }) as? StoreNode {
            vm.selectStore(storeNode.storeId)
            return
        }
        if let decNode = hits.first(where: { $0 is DecorationNode }) as? DecorationNode {
            vm.selectDecoration(decNode.decorationId)
            return
        }
        // Placement mode — tap in corridor places a decoration
        if let kind = vm.state.placingDecoration {
            let cs = sceneToCS(p)
            vm.placeDecoration(kind: kind, at: (x: Double(cs.x), y: Double(cs.y)))
            return
        }
        vm.clearSelection()
    }

    private func showThoughtAboveVisitor(id: UUID) {
        guard let vm, let node = visitorNodes[id] else { return }
        let text = vm.state.selectedVisitorThought
        guard !text.isEmpty else { return }
        // Remove any existing bubbles
        overlayLayer.children.filter { $0 is ThoughtBubbleNode }.forEach { $0.removeFromParent() }
        let bubble = ThoughtBubbleNode(text: text)
        bubble.position = CGPoint(x: node.position.x + 14, y: node.position.y + 40)
        bubble.zPosition = 200
        overlayLayer.addChild(bubble)
    }

    // MARK: Coord helpers — CSS space (y-down) ↔ Scene space (y-up)

    private func csToScene(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: size.height - y)
    }
    private func csToScene(x: Double, y: Double) -> CGPoint {
        csToScene(x: CGFloat(x), y: CGFloat(y))
    }
    private func sceneToCS(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: size.height - p.y)
    }
}

