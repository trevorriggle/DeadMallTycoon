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
    private let entrancesLayer = SKNode()
    private let visitorsLayer = SKNode()
    private let overlayLayer = SKNode()

    private var storeNodes: [Int: StoreNode] = [:]
    private var decorationNodes: [Int: DecorationNode] = [:]
    private var visitorNodes: [UUID: VisitorNode] = [:]
    private var northEntranceNode: EntranceNode?
    private var southEntranceNode: EntranceNode?

    // Entrance spawn/exit points in CSS coords. Centered at x=600 (the seam
    // between standard storefront slots 4 and 5), sitting on the corridor wall
    // line (y=128 north, y=388 south). Entrance nodes are 40×24pt at these points
    // — fully in the wall band without overlapping any storefront sprite.
    private static let northEntranceCSS = CGPoint(x: 600, y: 128)
    private static let southEntranceCSS = CGPoint(x: 600, y: 388)
    // Spawn slightly inside the corridor so visitors don't sit on the wall line.
    private static let northSpawnCSS = CGPoint(x: 600, y: 140)
    private static let southSpawnCSS = CGPoint(x: 600, y: 380)

    // Scene-local visitor presentation state — not in GameState, not observed.
    // Keeps 60fps position writes out of the Observation loop.
    private var visitors: [Visitor] = []
    // Tracks which entrance each visitor entered through, so leaving visitors
    // can prefer exiting the way they came (spec: "they exit the way they came").
    // Scene-local only — not persisted, not in GameState.
    private var visitorEntryWing: [UUID: Wing] = [:]
    // Phase 3 behavior state: phase machine + destination + post-shop bag tier +
    // last-shopped-at store id (for thought-bubble suffix). Keyed by visitor.id.
    // Cleared alongside visitorNodes on despawn / restart.
    private var visitorBehavior: [UUID: VisitorBehaviorState] = [:]
    private var visitorRNG = SeededGenerator(seed: UInt64.random(in: 1..<UInt64.max))

    // Phase 3 — state machine for visitor behavior. Replaces the old "v.state
    // == .leaving" + dwellTimer-based logic with explicit phases that encode
    // the next action to take when a pause elapses.
    enum NextAction: Equatable {
        case enterStore(storeId: Int)   // browsing pause done → despawn inside
        case newDestination              // reaction/post-shop pause done → re-pick
        case exit                        // reaction/post-shop pause done → head for entrance
    }
    enum VisitorDwellPhase: Equatable {
        case arriving                                          // walking to destination
        case paused(until: TimeInterval, next: NextAction)     // standing still, resumes with next
        case insideStore(storeId: Int, until: TimeInterval)    // despawned, reappears at until
        case exiting                                           // walking to an entrance
    }
    struct VisitorBehaviorState: Equatable {
        var phase: VisitorDwellPhase = .arriving
        var destinationStoreId: Int? = nil   // nil = wander destination
        var lastShoppedAt: Int? = nil        // for "Shopped at X" thought-bubble suffix
        var bagTier: StoreTier? = nil        // nil = no bag; set when emerging from a store
    }

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

        // Layer order: corridor floor, decorations, stores, entrances, visitors, overlays
        worldNode.addChild(decorationsLayer)
        worldNode.addChild(storesLayer)
        worldNode.addChild(entrancesLayer)
        worldNode.addChild(visitorsLayer)
        worldNode.addChild(overlayLayer)

        // Register observation: reconcile whenever any observable state property is read
        // the next time it changes. We continually re-register after each change so
        // reconciliation keeps happening over time.
        observeAndReconcile()

        // v8: initVisitors() — seed 12 visitors spread across the corridor in wandering state.
        seedInitialVisitors()
    }

    // v8: initVisitors() — 12 visitors at random corridor positions, each given
    // a real destination + random entry-wing record so the Phase 3 state machine
    // drives them forward on the first frame (no idle "no target" drift).
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
            var behavior = VisitorBehaviorState()
            assignFreshDestination(&v, &behavior, in: s)
            visitorEntryWing[v.id] = visitorRNG.chance(0.5) ? .north : .south
            visitorBehavior[v.id] = behavior
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
            _ = vm.state.northEntranceSealed
            _ = vm.state.southEntranceSealed
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
            visitorEntryWing.removeAll()
            visitorBehavior.removeAll()
            didSeedVisitors = false
        }
    }

    // MARK: Reconciliation — diff nodes against state

    private func reconcile(state: GameState) {
        reconcileStores(state)
        reconcileDecorations(state)
        reconcileEntrances(state)
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

    // Entrance reconcile — lazy create on first pass, toggle sealed state thereafter.
    // When a wing is player-sealed (wingsClosed), hide the entrance entirely — the
    // wing overlay handles the visual. Otherwise show it, sealed or not.
    private func reconcileEntrances(_ state: GameState) {
        if northEntranceNode == nil {
            let n = EntranceNode(wing: .north)
            n.position = csToScene(x: Self.northEntranceCSS.x, y: Self.northEntranceCSS.y)
            n.zPosition = 12
            entrancesLayer.addChild(n)
            northEntranceNode = n
        }
        if southEntranceNode == nil {
            let s = EntranceNode(wing: .south)
            s.position = csToScene(x: Self.southEntranceCSS.x, y: Self.southEntranceCSS.y)
            s.zPosition = 12
            entrancesLayer.addChild(s)
            southEntranceNode = s
        }
        northEntranceNode?.setSealed(state.northEntranceSealed)
        southEntranceNode?.setSealed(state.southEntranceSealed)
        northEntranceNode?.isHidden = Mall.isWingClosed(.north, in: state)
        southEntranceNode?.isHidden = Mall.isWingClosed(.south, in: state)
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

    // MARK: Visitor motion — Phase 3 scene-local state machine
    // Replaces the v8 port of updateVisitorPositions(). Each visitor walks a
    // four-phase lifecycle: arriving → paused → (insideStore) → paused → exiting.
    // Pause transitions encode the NextAction (enter/new-destination/exit) so the
    // same pause state covers pre-entry browsing, post-shop decision, and vacant-
    // storefront reactions without branching on timers elsewhere.
    //
    // All visitor pathing is scene-local — VisitorFactory.pickTarget is NO LONGER
    // called from here (the factory's spawn/targetCount are still used).

    override func update(_ currentTime: TimeInterval) {
        guard let vm else { return }
        let s = vm.state
        seedInitialVisitors()

        // Phase C — re-publish SwiftUI card anchors every frame while a selection exists.
        if s.selectedStoreId != nil || s.selectedDecorationId != nil {
            publishSelectionAnchors(s)
        }

        var toRemove: [UUID] = []
        for i in visitors.indices {
            var v = visitors[i]
            var behavior = visitorBehavior[v.id] ?? VisitorBehaviorState()

            // 1. Time-based phase transitions (paused timeouts, insideStore emerge).
            switch behavior.phase {
            case .paused(let until, let next) where currentTime >= until:
                switch next {
                case .enterStore(let storeId):
                    behavior.phase = .insideStore(
                        storeId: storeId,
                        until: currentTime + visitorRNG.double(in: 10..<30)
                    )
                case .newDestination:
                    assignFreshDestination(&v, &behavior, in: s)
                case .exit:
                    if let exit = chooseExitTarget(for: v.id, in: s) {
                        v.target = exit
                        behavior.phase = .exiting
                    } else {
                        toRemove.append(v.id)
                        visitorBehavior[v.id] = behavior
                        visitors[i] = v
                        continue
                    }
                }
            case .insideStore(let storeId, let until) where currentTime >= until:
                emergeFromStore(&v, &behavior, storeId: storeId, in: s, now: currentTime)
            default:
                break
            }

            // 2. Movement + arrival, for phases that move.
            switch behavior.phase {
            case .paused, .insideStore:
                break   // standing still or despawned
            case .arriving, .exiting:
                if v.target == nil, case .arriving = behavior.phase {
                    assignFreshDestination(&v, &behavior, in: s)
                }
                if let target = v.target {
                    let dx = target.x - v.x
                    let dy = target.y - v.y
                    let dist = (dx * dx + dy * dy).squareRoot()
                    let arriveRadius: Double = {
                        if case .exiting = behavior.phase { return 6 }
                        return 3
                    }()
                    if dist < arriveRadius {
                        switch behavior.phase {
                        case .exiting:
                            toRemove.append(v.id)
                        case .arriving:
                            handleDestinationArrival(
                                &v, &behavior,
                                destStoreId: behavior.destinationStoreId,
                                in: s, now: currentTime
                            )
                        default:
                            break
                        }
                    } else {
                        v.x += (dx / dist) * v.speed
                        v.y += (dy / dist) * v.speed
                    }
                }
            }

            visitorBehavior[v.id] = behavior
            visitors[i] = v
        }

        // Despawn removed.
        for id in toRemove {
            visitorNodes[id]?.removeFromParent()
            visitorNodes.removeValue(forKey: id)
            visitorEntryWing.removeValue(forKey: id)
            visitorBehavior.removeValue(forKey: id)
        }
        visitors.removeAll { toRemove.contains($0.id) }

        // Spawn — Phase 3 raises the visible target 2× and caps the total pool
        // at 150 so many-despawned-inside-store runs don't starve the corridor.
        // Uses VisitorFactory.targetVisitorCount as the base (unchanged).
        let visibleCount = visitors.reduce(0) { acc, vis in
            if case .insideStore = visitorBehavior[vis.id]?.phase { return acc }
            return acc + 1
        }
        let visibleTarget = VisitorFactory.targetVisitorCount(s) * 2
        let poolCap = 150
        if visibleCount < visibleTarget
            && visitors.count < poolCap
            && visitorRNG.chance(0.02) {
            if let (spawnCSS, wing) = chooseSpawnEntrance(in: s) {
                var v = VisitorFactory.spawn(state: s, rng: &visitorRNG)
                v.x = spawnCSS.x
                v.y = spawnCSS.y
                var behavior = VisitorBehaviorState()
                assignFreshDestination(&v, &behavior, in: s)
                visitorEntryWing[v.id] = wing
                visitorBehavior[v.id] = behavior
                visitors.append(v)
            }
        }

        // 3. Node sync — skip insideStore visitors (no render), refresh positions
        // + bag tint for everyone else.
        for v in visitors {
            let inside: Bool = {
                if case .insideStore = visitorBehavior[v.id]?.phase { return true }
                return false
            }()
            if inside {
                if let node = visitorNodes[v.id] {
                    node.removeFromParent()
                    visitorNodes.removeValue(forKey: v.id)
                }
                continue
            }
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
            visitorNodes[v.id]?.setBag(tier: visitorBehavior[v.id]?.bagTier)
        }
    }

    // Phase 3 helpers ------------------------------------------------------------

    // Arrived at a store destination. Branches on store state:
    // - open           → 2s browsing pause, then enter
    // - vacant (anchor)→ 10s stand-still "sad gap" reaction, then exit
    // - vacant (other) → 2s pause, 50/50 new destination or exit
    // - wander dest    → 80% re-pick, 20% exit immediately
    private func handleDestinationArrival(_ v: inout Visitor,
                                          _ behavior: inout VisitorBehaviorState,
                                          destStoreId: Int?,
                                          in s: GameState,
                                          now: TimeInterval) {
        if let id = destStoreId, let dest = s.stores.first(where: { $0.id == id }) {
            let isAnchorSlot = dest.position.w >= 180
            if dest.isVacant {
                if isAnchorSlot {
                    behavior.phase = .paused(until: now + 10.0, next: .exit)
                } else {
                    let nextAction: NextAction = visitorRNG.chance(0.5) ? .newDestination : .exit
                    behavior.phase = .paused(until: now + 2.0, next: nextAction)
                }
            } else {
                behavior.phase = .paused(until: now + 2.0, next: .enterStore(storeId: id))
            }
        } else {
            // Wander destination — mostly re-pick, occasionally leave.
            if visitorRNG.chance(0.2), let exit = chooseExitTarget(for: v.id, in: s) {
                v.target = exit
                behavior.phase = .exiting
            } else {
                assignFreshDestination(&v, &behavior, in: s)
            }
        }
    }

    // Re-emerges from a store: snaps to the storefront's approach position,
    // stamps lastShoppedAt + bagTier, then enters a 1s post-shop pause whose
    // NextAction is a 50/50 between picking another destination and exiting.
    private func emergeFromStore(_ v: inout Visitor,
                                  _ behavior: inout VisitorBehaviorState,
                                  storeId: Int,
                                  in s: GameState,
                                  now: TimeInterval) {
        guard let store = s.stores.first(where: { $0.id == storeId }) else {
            // Store no longer exists — force exit on next tick.
            behavior.phase = .paused(until: now + 0.1, next: .exit)
            return
        }
        let approach = storeApproachTarget(for: store)
        v.x = approach.x
        v.y = approach.y
        behavior.lastShoppedAt = storeId
        behavior.bagTier = store.tier
        let next: NextAction = visitorRNG.chance(0.5) ? .newDestination : .exit
        behavior.phase = .paused(until: now + 1.0, next: next)
    }

    // Picks a new destination (store or wander) + sets v.target and behavior.
    private func assignFreshDestination(_ v: inout Visitor,
                                         _ behavior: inout VisitorBehaviorState,
                                         in s: GameState) {
        let (target, storeId) = pickDestination(for: v, in: s)
        v.target = target
        v.targetType = (storeId != nil) ? "store" : "wander"
        behavior.destinationStoreId = storeId
        behavior.phase = .arriving
    }

    // Personality + archetype weighted destination picker. Scene-local replacement
    // for VisitorFactory.pickTarget (the factory is left untouched per spec).
    //
    // Selection order:
    //  1) Personality.preferredStores hit in the open-store pool (50% chance)
    //  2) Archetype-weighted tier pool (40% chance of picking from the pool):
    //       teens              → standard + sketchy
    //       elders (age ≥ 60)  → anchors
    //       kids               → kiosks (food court)
    //       everyone else      → all open stores
    //  3) Wander — random point in the corridor band
    private func pickDestination(for v: Visitor, in s: GameState)
        -> (target: VisitorTarget, storeId: Int?) {
        let personality = Personalities.all[v.personality] ?? Personalities.all["Casual Browser"]!
        let openStores = s.stores.filter {
            $0.tier != .vacant && !Mall.isWingClosed($0.wing, in: s)
        }

        let preferred = openStores.filter { personality.preferredStores.contains($0.name) }
        if !preferred.isEmpty, visitorRNG.chance(0.5), let store = visitorRNG.pick(preferred) {
            return (storeApproachTarget(for: store), store.id)
        }

        let archetypeCandidates: [Store] = {
            switch v.type {
            case .teen:
                return openStores.filter { $0.tier == .standard || $0.tier == .sketchy }
            case .elder where v.age >= 60:
                return openStores.filter { $0.tier == .anchor }
            case .kid:
                return openStores.filter { $0.tier == .kiosk }
            default:
                return openStores
            }
        }()
        if !archetypeCandidates.isEmpty,
           visitorRNG.chance(0.4),
           let store = visitorRNG.pick(archetypeCandidates) {
            return (storeApproachTarget(for: store), store.id)
        }

        return (VisitorTarget(
            x: 50 + visitorRNG.double(in: 0..<1100),
            y: 210 + visitorRNG.double(in: 0..<70),
            storeId: nil
        ), nil)
    }

    // Corridor-side approach point for a store. Anchor slots (full-height end
    // caps at the corridor ends) are approached from the corridor-side face.
    // Standard storefronts are approached from the edge nearest the corridor
    // (bottom for north wing, top for south wing).
    private func storeApproachTarget(for store: Store) -> VisitorTarget {
        let isAnchor = store.position.w >= 180
        if isAnchor {
            let leftSide = store.position.x < 600
            let cx = leftSide
                ? store.position.x + store.position.w + 15
                : store.position.x - 15
            return VisitorTarget(x: cx, y: 260, storeId: store.id)
        }
        let ty = store.wing == .north
            ? store.position.y + store.position.h + 15
            : store.position.y - 15
        return VisitorTarget(x: store.position.x + store.position.w / 2,
                             y: ty, storeId: store.id)
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
        var text = vm.state.selectedVisitorThought
        // Phase 3 — append "Shopped at [STORE_NAME]" suffix for recent shoppers.
        if let storeId = visitorBehavior[id]?.lastShoppedAt,
           let store = vm.state.stores.first(where: { $0.id == storeId }),
           !store.name.isEmpty {
            let suffix = "Shopped at \(store.name)"
            text = text.isEmpty ? suffix : "\(text)\n\(suffix)"
        }
        guard !text.isEmpty else { return }
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

    // MARK: Entrance routing

    // Returns a spawn point + entry-wing record, or nil if no usable entrance.
    // An entrance is usable when it isn't sealed AND its wing isn't player-sealed.
    private func chooseSpawnEntrance(in state: GameState) -> (pos: CGPoint, wing: Wing)? {
        let northUsable = !state.northEntranceSealed && !Mall.isWingClosed(.north, in: state)
        let southUsable = !state.southEntranceSealed && !Mall.isWingClosed(.south, in: state)
        switch (northUsable, southUsable) {
        case (true, true):
            return visitorRNG.chance(0.5)
                ? (Self.northSpawnCSS, .north)
                : (Self.southSpawnCSS, .south)
        case (true, false): return (Self.northSpawnCSS, .north)
        case (false, true): return (Self.southSpawnCSS, .south)
        default:            return nil
        }
    }

    // Returns a target representing the exit point for a leaving visitor.
    // Prefers the entrance they came in through; falls back to the other if sealed;
    // returns nil if no usable entrance (visitor should be despawned immediately).
    private func chooseExitTarget(for visitorId: UUID, in state: GameState) -> VisitorTarget? {
        let entryWing = visitorEntryWing[visitorId]
        let northUsable = !state.northEntranceSealed && !Mall.isWingClosed(.north, in: state)
        let southUsable = !state.southEntranceSealed && !Mall.isWingClosed(.south, in: state)
        if let entry = entryWing {
            if entry == .north, northUsable {
                return VisitorTarget(x: Self.northEntranceCSS.x, y: Self.northEntranceCSS.y, storeId: nil)
            }
            if entry == .south, southUsable {
                return VisitorTarget(x: Self.southEntranceCSS.x, y: Self.southEntranceCSS.y, storeId: nil)
            }
        }
        if northUsable {
            return VisitorTarget(x: Self.northEntranceCSS.x, y: Self.northEntranceCSS.y, storeId: nil)
        }
        if southUsable {
            return VisitorTarget(x: Self.southEntranceCSS.x, y: Self.southEntranceCSS.y, storeId: nil)
        }
        return nil
    }

    // MARK: Entrance node

    // Nested so it stays scoped to MallScene and doesn't fan out into a new file.
    // 40pt × 24pt double-door glyph: dark frame + warm glow + vertical mullion
    // (reads as double doors) + "MALL" sign on the corridor side. When sealed:
    // plywood overlay with horizontal plank lines and a "USE OTHER" tag.
    private final class EntranceNode: SKNode {
        private let wing: Wing
        private var sealedOverlay: SKNode?

        init(wing: Wing) {
            self.wing = wing
            super.init()

            let doorRect = CGRect(x: -20, y: -12, width: 40, height: 24)

            let glow = SKShapeNode(rect: doorRect.insetBy(dx: 2, dy: 2), cornerRadius: 2)
            glow.fillColor = Palette.windowLit
            glow.strokeColor = .clear
            glow.alpha = 0.55
            glow.zPosition = 0
            addChild(glow)

            let door = SKShapeNode(rect: doorRect, cornerRadius: 2)
            door.fillColor = Palette.gateDark
            door.strokeColor = Palette.signLight
            door.lineWidth = 2
            door.zPosition = 1
            addChild(door)

            // Vertical mullion — reads as a pair of doors.
            let mullion = SKShapeNode(rect: CGRect(x: -1, y: -12, width: 2, height: 24))
            mullion.fillColor = Palette.signLight
            mullion.strokeColor = .clear
            mullion.zPosition = 2
            addChild(mullion)

            // "MALL" sign on the corridor side. In SpriteKit y-up, north's
            // corridor lives at negative local y, south's at positive.
            let sign = SKLabelNode(fontNamed: "Courier-Bold")
            sign.text = "MALL"
            sign.fontSize = 9
            sign.fontColor = Palette.signLight
            sign.verticalAlignmentMode = .center
            sign.horizontalAlignmentMode = .center
            sign.position = CGPoint(x: 0, y: wing == .north ? -20 : 20)
            sign.zPosition = 2
            addChild(sign)
        }

        required init?(coder: NSCoder) { fatalError() }

        func setSealed(_ sealed: Bool) {
            if sealed {
                guard sealedOverlay == nil else { return }
                let overlay = SKNode()
                overlay.zPosition = 3

                let plywood = SKShapeNode(rect: CGRect(x: -20, y: -12, width: 40, height: 24))
                plywood.fillColor = Palette.storeBoarded
                plywood.strokeColor = Palette.storeBoardedBorder
                plywood.lineWidth = 2
                overlay.addChild(plywood)

                for i in 0..<3 {
                    let plank = SKShapeNode(rect: CGRect(x: -18, y: -10 + CGFloat(i) * 8,
                                                         width: 36, height: 1))
                    plank.strokeColor = Palette.storeAbandoned
                    plank.fillColor = Palette.storeAbandoned
                    plank.lineWidth = 1
                    overlay.addChild(plank)
                }

                let tag = SKLabelNode(fontNamed: "Courier-Bold")
                tag.text = "USE OTHER"
                tag.fontSize = 7
                tag.fontColor = Palette.wingSealedLabel
                tag.verticalAlignmentMode = .center
                tag.horizontalAlignmentMode = .center
                tag.position = CGPoint(x: 0, y: wing == .north ? -20 : 20)
                tag.zPosition = 4
                overlay.addChild(tag)

                addChild(overlay)
                sealedOverlay = overlay
            } else {
                sealedOverlay?.removeFromParent()
                sealedOverlay = nil
            }
        }
    }
}

