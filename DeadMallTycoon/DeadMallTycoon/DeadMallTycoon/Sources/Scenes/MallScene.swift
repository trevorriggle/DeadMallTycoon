import SpriteKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Observation

// The mall corridor renderer. Reads GameViewModel; mutates only via explicit player-action
// calls (selectVisitor, placeArtifact, etc.).
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

    // v9 Prompt 8 — worldNode is an SKEffectNode so a CIColorControls filter
    // can apply scene-wide brightness + saturation. shouldRasterize stays
    // false so the subtree keeps animating. HUD is SwiftUI above SpriteKit,
    // so UI is not affected by the filter.
    private let worldNode: SKEffectNode = {
        let n = SKEffectNode()
        n.shouldRasterize = false
        n.filter = CIFilter(name: "CIColorControls", parameters: [
            "inputBrightness": 0.0,   // additive, range [-1, 1]; 0 = no change
            "inputSaturation": 1.0,   // multiplicative, 1.0 = normal
            "inputContrast":   1.0,
        ])
        return n
    }()
    private let corridorNode = SKNode()

    // v9 Prompt 8 — environmental-visual scaffolding. Four overlays:
    //   - decayLayer       : procedural wear texture; above corridor, below stores.
    //   - flickerOverlay   : scene-wide black mask for per-state flicker flashes.
    //   - blackoutOverlay  : ghostMall-only longer full dimming events.
    //   - vignetteOverlay  : edge vignette when visitor isolation triggers.
    private let decayLayer = SKNode()
    private let flickerOverlay = SKShapeNode()
    private let blackoutOverlay = SKShapeNode()
    private let vignetteOverlay = SKNode()

    // Remember the last rendered EnvironmentState + decay age tier so we
    // know when to regenerate the decay texture / restart the ghostMall
    // blackout action / re-tween the filter. Start as nil so the first
    // reconcile always applies values.
    private var lastEnvironmentState: EnvironmentState?
    private var lastDecayAgeTier: Int = -1
    private let storesLayer = SKNode()
    private let decorationsLayer = SKNode()
    private let entrancesLayer = SKNode()
    private let visitorsLayer = SKNode()
    private let overlayLayer = SKNode()

    private var storeNodes: [Int: StoreNode] = [:]
    // v9 Prompt 3 — DecorationNode deleted; unified ArtifactNode renders all
    // placed artifacts. Keyed by Artifact.id. Ambient types (boardedStorefront,
    // sealedEntrance, emptyFoodCourt, custom) are skipped by reconcile.
    private var artifactNodes: [Int: ArtifactNode] = [:]
    private var visitorNodes: [UUID: VisitorNode] = [:]
    // v9 Prompt 6.5 — four corner entrances (NW/NE/SW/SE), keyed by corner.
    // Replaces the two wing-centered doors. Lazy-created in reconcileEntrances.
    private var entranceNodes: [EntranceCorner: EntranceNode] = [:]

    // v9 Prompt 6.5 — corner entrance positions in CSS coords.
    //
    // v9 patch (worldHeight 1400) — corner blocks are now x:0..200, y:0..90
    // (NW/NE) and x:0..200, y:1310..1400 (SW/SE). Doors sit near the world's
    // top/bottom edges so they read as "exiting OUT of the mall." Spawns
    // place visitors inside the upper or lower access corridor (y:90..200
    // and y:1200..1310), just past the door threshold.
    private static let entranceCSS: [EntranceCorner: CGPoint] = [
        .nw: CGPoint(x: 100, y: 30),
        .ne: CGPoint(x: 1100, y: 30),
        .sw: CGPoint(x: 100, y: 1370),
        .se: CGPoint(x: 1100, y: 1370),
    ]
    private static let spawnCSS: [EntranceCorner: CGPoint] = [
        .nw: CGPoint(x: 100, y: 145),
        .ne: CGPoint(x: 1100, y: 145),
        .sw: CGPoint(x: 100, y: 1255),
        .se: CGPoint(x: 1100, y: 1255),
    ]

    // Scene-local visitor presentation state — not in GameState, not observed.
    // Keeps 60fps position writes out of the Observation loop.
    private var visitors: [Visitor] = []
    // Tracks which corner each visitor entered through, so leaving visitors
    // can prefer exiting the way they came (spec: "they exit the way they came").
    // Scene-local only — not persisted, not in GameState.
    // v9 Prompt 6.5 — was visitorEntryWing; now per-corner.
    private var visitorEntryCorner: [UUID: EntranceCorner] = [:]
    // Phase 3 behavior state: phase machine + destination + post-shop bag tier +
    // last-shopped-at store id (for thought-bubble suffix). Keyed by visitor.id.
    // Cleared alongside visitorNodes on despawn / restart.
    private var visitorBehavior: [UUID: VisitorBehaviorState] = [:]
    private var visitorRNG = SeededGenerator(seed: UInt64.random(in: 1..<UInt64.max))

    // v9 Prompt 4 Phase 3 — per-visitor passive-thought clock. Each visitor
    // fires a silent thought every 20-30s; if the thought tags an artifact
    // (proximity gate in PersonalityPicker.pickThought), the VM increments
    // that artifact's memory weight by cohort-weighted amount. Scene-local,
    // not in GameState — this is presentation-layer cadence, not game logic.
    private var nextPassiveThoughtAt: [UUID: TimeInterval] = [:]
    private static let passiveThoughtMinInterval: TimeInterval = 20
    private static let passiveThoughtMaxInterval: TimeInterval = 30

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
        // v9 Prompt 6.5 fix — intermediate waypoints from current position to
        // v.target. Movement walks toward waypointQueue.first (or v.target
        // when queue is empty). Arrival pops the front; arrival at the final
        // target (queue empty) triggers the existing phase-transition logic.
        // Queue does NOT include v.target — it's the bend points only.
        var waypointQueue: [CGPoint] = []
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
        // MUST stay aspectFit — the scene is authored at GameConstants
        // worldWidth × worldHeight (1200 × 1400 post-stretch) and csToScene()
        // flips y relative to size.height. `.resizeFill` would stretch size
        // to the SKView bounds, making csToScene map positions incorrectly
        // whenever the SKView's aspect doesn't match the world's. MallSceneView
        // already sets this on present; repeating here so a future refactor
        // can't silently regress.
        scaleMode = .aspectFit

        buildStaticBackground()
        addChild(worldNode)
        worldNode.addChild(corridorNode)

        // v9 Prompt 8 — decay overlay sits above the corridor floor but
        // below stores so wear patterns show beneath storefront sprites.
        worldNode.addChild(decayLayer)
        decayLayer.zPosition = -40   // above corridor (-50), below stores (default 0)

        // Layer order: corridor floor, decay, decorations, stores, entrances, visitors, overlays
        worldNode.addChild(decorationsLayer)
        worldNode.addChild(storesLayer)
        worldNode.addChild(entrancesLayer)
        worldNode.addChild(visitorsLayer)
        worldNode.addChild(overlayLayer)

        // v9 Prompt 8 — flicker/blackout/vignette overlays live OUTSIDE the
        // effect node so the CIColorControls filter doesn't darken them
        // (they already ARE the darkening effect). Configured lazy; shapes
        // get their size set in didChangeSize.
        flickerOverlay.alpha = 0
        flickerOverlay.zPosition = 900
        flickerOverlay.isUserInteractionEnabled = false
        addChild(flickerOverlay)

        blackoutOverlay.alpha = 0
        blackoutOverlay.zPosition = 901
        blackoutOverlay.isUserInteractionEnabled = false
        addChild(blackoutOverlay)

        vignetteOverlay.alpha = 0
        vignetteOverlay.zPosition = 905
        vignetteOverlay.isUserInteractionEnabled = false
        addChild(vignetteOverlay)

        sizeEnvironmentOverlays()

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

    // v9 Prompt 8 fix — throttled per-frame isolation-vignette check. Visitor
    // count changes (spawn, despawn, enterStore) don't trigger the
    // observation-driven reconcile path, so the vignette needs its own
    // ticker. 1Hz is plenty for a 1.2s fade.
    private var lastIsolationCheckTime: TimeInterval = 0
    private func seedInitialVisitors() {
        guard let vm, vm.state.started, !didSeedVisitors else { return }
        didSeedVisitors = true
        let s = vm.state
        for _ in 0..<12 {
            var v = VisitorFactory.spawn(state: s, rng: &visitorRNG)
            // v9 patch — seed inside the new main corridor band (y:200..1200).
            // x range stays full mall width; planner routes around anchors.
            v.x = 250 + Double.random(in: 0..<700, using: &visitorRNG)
            v.y = 400 + Double.random(in: 0..<600, using: &visitorRNG)
            v.state = .wandering
            var behavior = VisitorBehaviorState()
            assignFreshDestination(&v, &behavior, in: s)
            // v9 Prompt 6.5 — seed visitor's entry corner uniformly at random
            // from all four. Initial seeding assumes all corners open; Mall
            // openness is checked on actual spawns, not this first-frame seed.
            visitorEntryCorner[v.id] = EntranceCorner.allCases.randomElement(using: &visitorRNG) ?? .nw
            visitorBehavior[v.id] = behavior
            visitors.append(v)
        }
    }

    // MARK: Passive thoughts (v9 Prompt 4 Phase 3)

    // v9 Prompt 4 Phase 3 — passive thought firing. Each visitor has a
    // private timer; when it elapses, a Thought is generated for them at
    // their current position. If the thought tags an artifact, the VM
    // increments that artifact's memory weight. Silent — no bubble, no
    // thoughts-log entry. The mall is being remembered by everyone in it,
    // whether the player is watching or not.
    private func tickPassiveThoughts(now: TimeInterval) {
        guard let vm else { return }
        for v in visitors {
            if let next = nextPassiveThoughtAt[v.id] {
                if now >= next {
                    vm.firePassiveThought(for: v)
                    nextPassiveThoughtAt[v.id] = scheduleNextThought(now: now)
                }
            } else {
                // First pass — schedule without firing. Staggers the initial
                // cohort so we don't get a synchronized volley.
                nextPassiveThoughtAt[v.id] = scheduleNextThought(now: now)
            }
        }
        // Garbage-collect timers for despawned visitors.
        let liveIds = Set(visitors.map(\.id))
        for id in nextPassiveThoughtAt.keys where !liveIds.contains(id) {
            nextPassiveThoughtAt.removeValue(forKey: id)
        }
    }

    private func scheduleNextThought(now: TimeInterval) -> TimeInterval {
        let span = Self.passiveThoughtMaxInterval - Self.passiveThoughtMinInterval
        let jitter = visitorRNG.double(in: 0..<span)
        return now + Self.passiveThoughtMinInterval + jitter
    }

    // MARK: Static background (floor / ceiling / walls / sealed wings)

    private func buildStaticBackground() {
        // CSS coord system: (0,0) top-left, y increases down.
        // SpriteKit: (0,0) bottom-left. Convert via sceneY().
        //
        // v9 — all three regions use the authored floor tile so the entire
        // mall scene reads as one continuous floor (the original
        // Palette.ceilingBg fill was near-black #1a1a22, which read as
        // "black voids" above and below the corridor). Half-scale the
        // tile (64pt instead of the asset's natural 128pt) for a denser
        // pattern that matches the storefront proportions.
        let floorTile = TextureFactory.floorTile()
        let tileSize = CGSize(width: 64, height: 64)

        // ceiling-bg: top strip (above corridor — contains north row).
        addTiled(texture: floorTile, tileSize: tileSize,
                 rectCSS: CGRect(x: 0, y: 0,
                                  width: GameConstants.worldWidth,
                                  height: GameConstants.corridorTop))

        // floor-bg: bottom strip (below corridor — contains south row).
        addTiled(texture: floorTile, tileSize: tileSize,
                 rectCSS: CGRect(x: 0, y: GameConstants.corridorBottom,
                                  width: GameConstants.worldWidth,
                                  height: GameConstants.worldHeight - GameConstants.corridorBottom))

        // corridor: the central walkable band between the storefront rows.
        addTiled(texture: floorTile, tileSize: tileSize,
                 rectCSS: CGRect(x: 0, y: GameConstants.corridorTop,
                                  width: GameConstants.worldWidth,
                                  height: GameConstants.corridorBottom - GameConstants.corridorTop))

        // walls: thin horizontal strips at y=128 and y=388
        // v9 patch — walls at the seams between storefront row and access
        // corridor. North row ends at y:90 → wall just below at y:88.
        // South row starts at y:1310 → wall just above at y:1312.
        addWall(atCSSy: 88)
        addWall(atCSSy: 1312)
    }

    // v9 — `tileSize` lets callers render a texture at a non-natural size
    // (e.g., the 128px authored floor tile rendered at 64pt for half-scale
    // density). When omitted, falls back to the texture's intrinsic size
    // for backwards compatibility with non-floor tiles.
    private func addTiled(texture: SKTexture,
                          tileSize: CGSize? = nil,
                          rectCSS: CGRect) {
        let renderSize = tileSize ?? texture.size()
        var y: CGFloat = 0
        while y < rectCSS.height {
            var x: CGFloat = 0
            while x < rectCSS.width {
                let sprite = SKSpriteNode(texture: texture)
                sprite.size = renderSize
                sprite.position = csToScene(x: rectCSS.origin.x + x + renderSize.width / 2,
                                            y: rectCSS.origin.y + y + renderSize.height / 2)
                sprite.zPosition = -100
                corridorNode.addChild(sprite)
                x += renderSize.width
            }
            y += renderSize.height
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
            _ = vm.state.artifacts           // v9 Prompt 3 — was state.decorations
            _ = vm.state.wingsClosed
            _ = vm.state.wingsDowngraded
            _ = vm.state.sealedEntrances
            _ = vm.state.selectedVisitorId
            _ = vm.state.selectedStoreId
            _ = vm.state.started
            _ = vm.state.gameover
            // v9 Prompt 8 — env state is a function of (Mall.state, monthsInDeadState).
            // Touch monthsInDeadState directly so the observer picks up
            // the ghostMall transition. Mall.state is recomputed from
            // already-touched fields above.
            _ = vm.state.monthsInDeadState
            _ = vm.state.year
            _ = vm.state.month
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
            visitorEntryCorner.removeAll()
            visitorBehavior.removeAll()
            didSeedVisitors = false
        }
    }

    // MARK: Reconciliation — diff nodes against state

    private func reconcile(state: GameState) {
        reconcileStores(state)
        reconcileArtifacts(state)        // v9 Prompt 3 — was reconcileDecorations
        reconcileEntrances(state)
        reconcileSealedWings(state)
        reconcileWingTint(state)        // Phase C — red tint on wings about to fail
        reconcileThreatFlash(state)     // Phase C — vignette flash when entering critical
        reconcileDim(state)
        publishSelectionAnchors(state)  // Phase C — SwiftUI card pinning
        // v9 Prompt 8 — environmental visual state machine. Drives the
        // CIColorControls filter, fluorescent flicker, ghostMall blackout,
        // decay overlay, isolation vignette, and ambient hum volume.
        reconcileEnvironment(state)
        // visitor selection highlight (visitors themselves are scene-local)
        for (id, node) in visitorNodes {
            node.markSelected(state.selectedVisitorId == id)
        }
    }

    // Entrance reconcile — lazy create on first pass, toggle sealed state thereafter.
    // When a wing is player-sealed (wingsClosed), hide both of its corners'
    // doors entirely — the wing overlay handles the visual. Otherwise show,
    // with per-corner sealed plywood when sealedEntrances contains the corner.
    //
    // v9 Prompt 6.5 — was two wing-centered doors (north/south); now four
    // corner doors keyed by EntranceCorner.
    private func reconcileEntrances(_ state: GameState) {
        for corner in EntranceCorner.allCases {
            if entranceNodes[corner] == nil {
                let node = EntranceNode(corner: corner)
                if let pos = Self.entranceCSS[corner] {
                    node.position = csToScene(x: pos.x, y: pos.y)
                }
                node.zPosition = 12
                entrancesLayer.addChild(node)
                entranceNodes[corner] = node
            }
            entranceNodes[corner]?.setSealed(state.sealedEntrances.contains(corner))
            entranceNodes[corner]?.isHidden = Mall.isWingClosed(corner.wing, in: state)
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
        // v9 Prompt 3 — decorationNodes → artifactNodes. selectedDecorationId
        // field is kept (Prompt 2 storage name) but now keys into ArtifactNodes.
        let decPt = anchorInView(for: state.selectedDecorationId.flatMap { artifactNodes[$0] })
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

    // v8: the decoration reconcile loop — iterated G.decorations.
    // v9 Prompt 3 — iterates state.artifacts. Ambient types (catalog cost == 0)
    // are skipped here because they have no corridor position / sprite
    // representation; the storefront texture flip (Prompt 2) handles the
    // visual for boardedStorefront, and the other ambient types aren't yet
    // consumed by mechanics either. Every placeable artifact with a non-nil
    // (x, y) gets an ArtifactNode sprite.
    private func reconcileArtifacts(_ state: GameState) {
        let renderable = state.artifacts.filter { a in
            guard ArtifactCatalog.info(a.type).cost > 0 else { return false }
            return a.x != nil && a.y != nil
        }
        let seen = Set(renderable.map { $0.id })
        for id in artifactNodes.keys where !seen.contains(id) {
            artifactNodes[id]?.removeFromParent()
            artifactNodes.removeValue(forKey: id)
        }
        for a in renderable {
            let size = ArtifactCatalog.info(a.type).size
            guard let ax = a.x, let ay = a.y else { continue }
            let scenePos = csToScene(x: ax + size.width / 2, y: ay + size.height / 2)
            if let node = artifactNodes[a.id] {
                node.position = scenePos
                node.apply(artifact: a)
            } else {
                let node = ArtifactNode(artifact: a)
                node.position = scenePos
                node.zPosition = 5
                decorationsLayer.addChild(node)
                artifactNodes[a.id] = node
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

        // v9 Prompt 4 Phase 3 — passive thoughts. For every visitor whose
        // clock has elapsed, fire a thought via the VM and schedule the next.
        tickPassiveThoughts(now: currentTime)

        // v9 Prompt 8 fix — keep the isolation vignette tracking visitor
        // count changes that don't trigger reconcile (spawn, despawn,
        // enterStore/emerge). 1Hz cadence is cheap and matches the 1.2s
        // fade tween.
        if currentTime - lastIsolationCheckTime >= 1.0 {
            lastIsolationCheckTime = currentTime
            reconcileIsolationVignette()
        }

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
                        // v9 Prompt 6.5 fix — plan H-shape route to exit door.
                        behavior.waypointQueue = Self.planPath(
                            from: CGPoint(x: v.x, y: v.y),
                            to: CGPoint(x: exit.x, y: exit.y)
                        )
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
                    // v9 Prompt 6.5 fix — consume waypoint queue first; once
                    // empty, head to the final target. Each waypoint pops on
                    // arrival; the final-target arrival triggers phase logic.
                    let stepTarget: CGPoint = behavior.waypointQueue.first
                        ?? CGPoint(x: target.x, y: target.y)
                    let isFinalStep = behavior.waypointQueue.isEmpty

                    let dx = stepTarget.x - v.x
                    let dy = stepTarget.y - v.y
                    let dist = (dx * dx + dy * dy).squareRoot()
                    let arriveRadius: Double = {
                        if !isFinalStep { return 4 }   // looser snap on intermediate waypoints
                        if case .exiting = behavior.phase { return 6 }
                        return 3
                    }()

                    if dist < arriveRadius {
                        if !isFinalStep {
                            // Pop the waypoint we just reached.
                            behavior.waypointQueue.removeFirst()
                        } else {
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
                        }
                    } else {
                        // Compute intended movement, then apply local artifact
                        // sidestep so visitors push around obstacle artifacts
                        // (kugel ball, fountain, etc.) instead of clipping.
                        let intendedX = v.x + (dx / dist) * v.speed
                        let intendedY = v.y + (dy / dist) * v.speed
                        let after = applyArtifactSidestep(
                            intended: CGPoint(x: intendedX, y: intendedY),
                            current: CGPoint(x: v.x, y: v.y),
                            in: s
                        )
                        v.x = after.x
                        v.y = after.y
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
            visitorEntryCorner.removeValue(forKey: id)
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
            if let (spawnPos, corner) = chooseSpawnEntrance(in: s) {
                var v = VisitorFactory.spawn(state: s, rng: &visitorRNG)
                v.x = spawnPos.x
                v.y = spawnPos.y
                var behavior = VisitorBehaviorState()
                assignFreshDestination(&v, &behavior, in: s)
                visitorEntryCorner[v.id] = corner
                visitorBehavior[v.id] = behavior
                visitors.append(v)
            }
        }

        // 3. Node sync — skip insideStore visitors (no render), refresh positions
        // + bag tint for everyone else.
        // v9 Prompt 8 — compute corridor-visible visitor count ONCE so every
        // node gets the same isolation answer this frame.
        let corridorVisitorCount = visitors.filter { v -> Bool in
            if case .insideStore = visitorBehavior[v.id]?.phase { return false }
            return true
        }.count
        let isolationActive = corridorVisitorCount < EnvironmentTuning.isolationThreshold

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
            visitorNodes[v.id]?.setIsolated(isolationActive)
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
                // v9 Prompt 6.5 fix — plan H-shape route to exit door.
                behavior.waypointQueue = Self.planPath(
                    from: CGPoint(x: v.x, y: v.y),
                    to: CGPoint(x: exit.x, y: exit.y)
                )
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
        // v9 Prompt 6.5 fix — plan a route through the H-shape walkable
        // geometry. Empty queue means direct path to v.target works.
        behavior.waypointQueue = Self.planPath(
            from: CGPoint(x: v.x, y: v.y),
            to: CGPoint(x: target.x, y: target.y)
        )
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

        // v9 patch — wander destinations land inside the main corridor band
        // (y:200..1200 in the stretched world). x kept loose; planner routes
        // around anchor rects when needed.
        return (VisitorTarget(
            x: 50 + visitorRNG.double(in: 0..<1100),
            y: 300 + visitorRNG.double(in: 0..<800),
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
            // v9 patch — anchor approach y lands in the center of the stretched
            // main corridor (y:200..1200 midpoint = 700).
            return VisitorTarget(x: cx, y: 700, storeId: store.id)
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
        // v9 Prompt 3 — DecorationNode → ArtifactNode. selectDecoration still
        // stores the id in selectedDecorationId (legacy field name retained).
        if let artNode = hits.first(where: { $0 is ArtifactNode }) as? ArtifactNode {
            vm.selectDecoration(artNode.artifactId)
            return
        }
        // Placement mode — tap in corridor places the chosen artifact type.
        if let type = vm.state.placingArtifactType {
            let cs = sceneToCS(p)
            vm.placeArtifact(type: type, at: (x: Double(cs.x), y: Double(cs.y)))
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

    // MARK: Path planning

    // v9 Prompt 6.5 fix — H-shape walkable geometry constants.
    // v9 patch — values updated for worldHeight 1400. Main corridor band
    // is y:200..1200 (h:1000) flanked by Sears (x<200) / JCPenney (x>1000).
    // Access corridors at y:90..200 (upper, 110pt) and y:1200..1310 (lower,
    // 110pt) span full mall width and are the only path between corner
    // blocks and the main corridor.
    private static let mainCorridorWestX: Double  = 200    // east edge of west anchor
    private static let mainCorridorEastX: Double  = 1000   // west edge of east anchor
    private static let mainCorridorNorthY: Double = 200    // top of anchors / bottom of upper access
    private static let mainCorridorSouthY: Double = 1200   // bottom of anchors / top of lower access
    private static let upperAccessTopY: Double    = 90     // bottom of north row
    private static let lowerAccessBottomY: Double = 1310   // top of south row
    private static let upperAccessLaneY: Double   = 145    // preferred lane (mid of upper access)
    private static let lowerAccessLaneY: Double   = 1255   // preferred lane (mid of lower access)
    // Gate x: where corner-column traffic enters the main corridor. 10pt
    // inside the main corridor so visitors don't skim Sears/JCPenney walls.
    private static let westGateX: Double = 210
    private static let eastGateX: Double = 990

    /// Routes a visitor path through the H-shaped walkable geometry, emitting
    /// intermediate waypoints. The final element is NOT included — that's
    /// the visitor's `v.target`. Returns an empty list if no bends are needed.
    static func planPath(from: CGPoint, to: CGPoint) -> [CGPoint] {
        var waypoints: [CGPoint] = []
        var cur = from
        func push(_ p: CGPoint) {
            if abs(p.x - cur.x) > 0.5 || abs(p.y - cur.y) > 0.5 {
                waypoints.append(p)
                cur = p
            }
        }

        let srcInWestCol = cur.x < mainCorridorWestX
        let srcInEastCol = cur.x > mainCorridorEastX
        let srcInCornerCol = srcInWestCol || srcInEastCol
        let srcAboveMall = cur.y < upperAccessTopY
        let srcBelowMall = cur.y > lowerAccessBottomY

        let tgtInWestCol = to.x < mainCorridorWestX
        let tgtInEastCol = to.x > mainCorridorEastX
        let tgtInCornerCol = tgtInWestCol || tgtInEastCol

        // 1. Escape source corner block to the nearest access corridor.
        if srcInCornerCol && srcAboveMall {
            push(CGPoint(x: cur.x, y: upperAccessLaneY))
        } else if srcInCornerCol && srcBelowMall {
            push(CGPoint(x: cur.x, y: lowerAccessLaneY))
        }

        // 2. If source is in corner column AND target is on the other side
        //    (or in main column), slide along the access corridor to the
        //    main-corridor gate before any vertical motion.
        let needsSourceGate: Bool = {
            guard srcInCornerCol else { return false }
            if srcInWestCol && tgtInWestCol { return false }
            if srcInEastCol && tgtInEastCol { return false }
            return true
        }()
        if needsSourceGate {
            let gateX = srcInWestCol ? westGateX : eastGateX
            push(CGPoint(x: gateX, y: cur.y))
        }

        // 3. If target is in a corner column (and source isn't on the same
        //    side), route via the target's access corridor.
        if tgtInCornerCol {
            let sameWestSide = srcInWestCol && tgtInWestCol
            let sameEastSide = srcInEastCol && tgtInEastCol
            if !sameWestSide && !sameEastSide {
                let tgtAccessY: Double? = {
                    if to.y < mainCorridorNorthY { return upperAccessLaneY }
                    if to.y > mainCorridorSouthY { return lowerAccessLaneY }
                    return nil   // target at main-corridor y, in a corner col → inside an anchor; unreachable
                }()
                if let accessY = tgtAccessY {
                    if abs(cur.y - accessY) > 1 {
                        push(CGPoint(x: cur.x, y: accessY))
                    }
                    let tgtGateX = tgtInWestCol ? westGateX : eastGateX
                    push(CGPoint(x: tgtGateX, y: accessY))
                }
            }
        }

        // 4. Final dogleg. If current and target differ in BOTH dimensions,
        //    insert an L-corner so motion is rectilinear (avoids diagonals
        //    that could clip store rects at the corridor seam).
        if abs(cur.x - to.x) > 1 && abs(cur.y - to.y) > 1 {
            push(CGPoint(x: to.x, y: cur.y))
        }

        return waypoints
    }

    // MARK: Local artifact avoidance

    // v9 Prompt 6.5 fix — push the visitor's intended position out of any
    // .obstacle artifact's avoidance circle. Reads ArtifactPathingClass from
    // the catalog so new artifact types automatically participate (or don't,
    // for .floor / .ceiling) without touching this code.
    //
    // Avoidance radius = max(width, height) / 2 + clearance. Visitors only
    // get a single sidestep per frame (one closest obstacle); on the next
    // frame, movement re-aims toward the waypoint and another sidestep can
    // fire if needed. Cumulatively reads as "bump and step around."
    private func applyArtifactSidestep(intended: CGPoint, current: CGPoint, in state: GameState) -> CGPoint {
        let visitorClearance: Double = 6
        for a in state.artifacts {
            guard let ax = a.x, let ay = a.y else { continue }
            guard ArtifactCatalog.pathingClass(for: a.type) == .obstacle else { continue }
            let info = ArtifactCatalog.info(a.type)
            let radius = max(info.size.width, info.size.height) / 2 + visitorClearance
            let dx = intended.x - ax
            let dy = intended.y - ay
            let dist = (dx * dx + dy * dy).squareRoot()
            if dist < radius {
                // Project the visitor onto the avoidance circle's edge.
                // If the visitor is exactly on the artifact (dist == 0), nudge
                // perpendicular to current heading so they don't get stuck.
                if dist < 0.01 {
                    let hx = intended.x - current.x
                    let hy = intended.y - current.y
                    let hLen = (hx * hx + hy * hy).squareRoot()
                    if hLen > 0.01 {
                        return CGPoint(x: ax + (-hy / hLen) * radius,
                                       y: ay + (hx / hLen) * radius)
                    }
                    return CGPoint(x: ax + radius, y: ay)
                }
                return CGPoint(x: ax + (dx / dist) * radius,
                               y: ay + (dy / dist) * radius)
            }
        }
        return intended
    }

    // MARK: Entrance routing

    // v9 Prompt 6.5 — picks uniformly at random from open corners; spawn
    // position is that corner's spawnCSS (visitor enters AT the corner door
    // and walks inward). Returns nil if every corner is sealed or its wing
    // is closed.
    private func chooseSpawnEntrance(in state: GameState) -> (pos: CGPoint, corner: EntranceCorner)? {
        let open = Mall.openEntrances(in: state)
        guard !open.isEmpty,
              let picked = open.randomElement(using: &visitorRNG),
              let pos = Self.spawnCSS[picked]
        else { return nil }
        return (pos, picked)
    }

    // v9 Prompt 6.5 — exit preference for leaving visitors.
    // Prefers the corner they came in through; falls back to any open corner;
    // returns nil if no usable entrance (visitor despawns immediately).
    private func chooseExitTarget(for visitorId: UUID, in state: GameState) -> VisitorTarget? {
        let open = Mall.openEntrances(in: state)
        guard !open.isEmpty else { return nil }

        // Prefer the entry corner if it's still open.
        if let entry = visitorEntryCorner[visitorId],
           open.contains(entry),
           let pos = Self.entranceCSS[entry] {
            return VisitorTarget(x: pos.x, y: pos.y, storeId: nil)
        }
        // Otherwise head for any open corner. Deterministic choice (first
        // in allCases order) so exit paths are reproducible in replays.
        for corner in EntranceCorner.allCases where open.contains(corner) {
            if let pos = Self.entranceCSS[corner] {
                return VisitorTarget(x: pos.x, y: pos.y, storeId: nil)
            }
        }
        return nil
    }

    // MARK: Entrance node

    // Nested so it stays scoped to MallScene and doesn't fan out into a new file.
    // 40pt × 24pt double-door glyph: dark frame + warm glow + vertical mullion
    // (reads as double doors). Sealed state overlays plywood with horizontal
    // planks.
    //
    // v9 Prompt 6.5 — EntranceNode now takes an EntranceCorner instead of a
    // Wing, and the "MALL" / "USE OTHER" text labels are removed per design
    // direction: a door sprite reads as a door without annotation. The
    // corner parameter is retained for future asymmetric visuals (e.g.,
    // directional cues toward the corridor) but the current draw is
    // symmetric and orientation-agnostic.
    // v9 patch — 80×48 mall double-door glyph (was 40×24, read as a small
    // dark square). Frame, two glass panes with warm glow, vertical
    // mullion, transom header, two horizontal handles. Sealed state
    // overlays plywood with horizontal plank lines, scaled to new size.
    private final class EntranceNode: SKNode {
        // swiftlint:disable:next unused_declaration
        private let corner: EntranceCorner
        private var sealedOverlay: SKNode?

        // Door geometry — single source of truth; sealed overlay reads these.
        private static let doorWidth:     CGFloat = 80
        private static let doorHeight:    CGFloat = 48
        private static let transomHeight: CGFloat = 8

        init(corner: EntranceCorner) {
            self.corner = corner
            super.init()

            let halfW = Self.doorWidth / 2
            let bodyHeight = Self.doorHeight - Self.transomHeight
            let bodyRect = CGRect(x: -halfW,
                                   y: -Self.doorHeight / 2,
                                   width: Self.doorWidth,
                                   height: bodyHeight)
            let transomRect = CGRect(x: -halfW,
                                      y: bodyRect.maxY,
                                      width: Self.doorWidth,
                                      height: Self.transomHeight)

            // Warm glow behind glass panes — "lit from within."
            let glow = SKShapeNode(rect: bodyRect.insetBy(dx: 3, dy: 3), cornerRadius: 2)
            glow.fillColor = Palette.windowLit
            glow.strokeColor = .clear
            glow.alpha = 0.6
            glow.zPosition = 0
            addChild(glow)

            // Glass-panel frame outline.
            let frame = SKShapeNode(rect: bodyRect, cornerRadius: 2)
            frame.fillColor = .clear
            frame.strokeColor = Palette.signLight
            frame.lineWidth = 2
            frame.zPosition = 1
            addChild(frame)

            // Transom header strip above the doors (lintel / sign band).
            let transom = SKShapeNode(rect: transomRect, cornerRadius: 1)
            transom.fillColor = Palette.gateDark
            transom.strokeColor = Palette.signLight
            transom.lineWidth = 2
            transom.zPosition = 1
            addChild(transom)

            // Vertical mullion — splits the two glass doors.
            let mullion = SKShapeNode(rect: CGRect(x: -1.5, y: bodyRect.minY,
                                                    width: 3, height: bodyHeight))
            mullion.fillColor = Palette.signLight
            mullion.strokeColor = .clear
            mullion.zPosition = 2
            addChild(mullion)

            // Two horizontal handles flanking the mullion. Push/pull bars.
            let handleY = bodyRect.midY - 1
            for offset in [CGFloat(-12), CGFloat(4)] {
                let handle = SKShapeNode(rect: CGRect(x: offset, y: handleY,
                                                       width: 8, height: 3))
                handle.fillColor = Palette.signLight
                handle.strokeColor = .clear
                handle.zPosition = 3
                addChild(handle)
            }
        }

        required init?(coder: NSCoder) { fatalError() }

        func setSealed(_ sealed: Bool) {
            if sealed {
                guard sealedOverlay == nil else { return }
                let overlay = SKNode()
                overlay.zPosition = 4

                let halfW = Self.doorWidth / 2
                let halfH = Self.doorHeight / 2
                let plywood = SKShapeNode(rect: CGRect(x: -halfW, y: -halfH,
                                                       width: Self.doorWidth,
                                                       height: Self.doorHeight))
                plywood.fillColor = Palette.storeBoarded
                plywood.strokeColor = Palette.storeBoardedBorder
                plywood.lineWidth = 2
                overlay.addChild(plywood)

                // Five plank lines spaced across the door height.
                let plankSpacing = Self.doorHeight / 6
                for i in 1..<6 {
                    let y = -halfH + CGFloat(i) * plankSpacing
                    let plank = SKShapeNode(rect: CGRect(x: -halfW + 2, y: y,
                                                          width: Self.doorWidth - 4, height: 1))
                    plank.strokeColor = Palette.storeAbandoned
                    plank.fillColor = Palette.storeAbandoned
                    plank.lineWidth = 1
                    overlay.addChild(plank)
                }

                addChild(overlay)
                sealedOverlay = overlay
            } else {
                sealedOverlay?.removeFromParent()
                sealedOverlay = nil
            }
        }
    }

    // MARK: v9 Prompt 8 — environmental visual state

    // Size the scene-wide flicker/blackout/vignette overlays to the full
    // scene rect. Called once from didMove and on any size change.
    private func sizeEnvironmentOverlays() {
        let rect = CGRect(origin: .zero, size: size)
        flickerOverlay.path = CGPath(rect: rect, transform: nil)
        flickerOverlay.fillColor = .black
        flickerOverlay.strokeColor = .clear

        blackoutOverlay.path = CGPath(rect: rect, transform: nil)
        blackoutOverlay.fillColor = .black
        blackoutOverlay.strokeColor = .clear

        // Vignette: four darkened border shapes layered at the scene edges
        // (top, bottom, left, right). Cheaper than a radial gradient and
        // reads as "remaining visitors are isolated in a dim corridor."
        vignetteOverlay.removeAllChildren()
        let thickness: CGFloat = min(size.width, size.height) * 0.22
        let color = SKColor(white: 0, alpha: 1)
        for rectSpec in [
            CGRect(x: 0, y: 0, width: size.width, height: thickness),
            CGRect(x: 0, y: size.height - thickness, width: size.width, height: thickness),
            CGRect(x: 0, y: 0, width: thickness, height: size.height),
            CGRect(x: size.width - thickness, y: 0, width: thickness, height: size.height),
        ] {
            let edge = SKShapeNode(rect: rectSpec)
            edge.fillColor = color
            edge.strokeColor = .clear
            edge.alpha = 0.7
            vignetteOverlay.addChild(edge)
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        sizeEnvironmentOverlays()
    }

    // Main reconcile entry for environmental visual state. Called once per
    // observation pass (see reconcile()) to keep the filter, decay texture,
    // flicker action, and vignette in sync with GameState.
    private func reconcileEnvironment(_ state: GameState) {
        let env = EnvironmentState.from(state)
        let ageMonths = (state.year - GameConstants.startingYear) * 12 + state.month
        let ageTier = max(0, ageMonths / EnvironmentTuning.decayAgeTierMonths)

        let envChanged = (env != lastEnvironmentState)
        let decayChanged = envChanged || (ageTier != lastDecayAgeTier)

        if envChanged {
            applyEnvironmentFilter(for: env)
            restartFlickerAction(for: env)
            restartGhostBlackoutAction(for: env)
            AmbientHumPlayer.shared.setVolume(
                EnvironmentTuning.ambientHumVolume[env] ?? 0.0
            )
            lastEnvironmentState = env
        }

        if decayChanged {
            rebuildDecayLayer(state: env, ageTier: ageTier)
            lastDecayAgeTier = ageTier
        }

        reconcileIsolationVignette()
    }

    // Smooth CIColorControls tween. brightness: multiplier 0..1 mapped to
    // inputBrightness (multiplier - 1.0) which is -1..0 (dimming only);
    // saturation: direct multiplier.
    private func applyEnvironmentFilter(for env: EnvironmentState) {
        let targetBrightness = (EnvironmentTuning.brightnessMultipliers[env] ?? 1.0) - 1.0
        let targetSaturation = EnvironmentTuning.saturationMultipliers[env] ?? 1.0

        guard let filter = worldNode.filter else { return }
        let startBrightness = (filter.value(forKey: "inputBrightness") as? Double) ?? 0.0
        let startSaturation = (filter.value(forKey: "inputSaturation") as? Double) ?? 1.0
        let duration = EnvironmentTuning.transitionDuration

        worldNode.removeAction(forKey: "envFilterTween")
        let action = SKAction.customAction(withDuration: duration) { [weak self] _, elapsed in
            guard let self, let filter = self.worldNode.filter else { return }
            let t = min(1.0, max(0.0, elapsed / CGFloat(duration)))
            let b = startBrightness + (targetBrightness - startBrightness) * Double(t)
            let s = startSaturation + (targetSaturation - startSaturation) * Double(t)
            filter.setValue(b, forKey: "inputBrightness")
            filter.setValue(s, forKey: "inputSaturation")
        }
        worldNode.run(action, withKey: "envFilterTween")
    }

    // Per-state flicker — probabilistic scene-wide brightness dip every
    // tickish (1s check cadence). Independent of the smooth state-transition
    // tween: the tween runs on the CIColorControls filter, the flicker runs
    // on the flickerOverlay alpha.
    private func restartFlickerAction(for env: EnvironmentState) {
        flickerOverlay.removeAllActions()
        let rate = EnvironmentTuning.fluorescentFlickerRate[env] ?? 0.0
        guard rate > 0 else {
            flickerOverlay.alpha = 0
            return
        }
        let checkCadence: TimeInterval = 1.0
        let flashDuration = EnvironmentTuning.flickerFlashDuration
        let rollAndMaybeFlash = SKAction.run { [weak self] in
            guard let self else { return }
            if Double.random(in: 0..<1) < rate {
                let half = flashDuration / 2
                self.flickerOverlay.run(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.55, duration: half),
                    SKAction.fadeAlpha(to: 0.0, duration: half),
                ]))
            }
        }
        let loop = SKAction.repeatForever(SKAction.sequence([
            rollAndMaybeFlash,
            SKAction.wait(forDuration: checkCadence),
        ]))
        flickerOverlay.run(loop)
    }

    // Ghost Mall-only periodic full-corridor lighting failure. Separate
    // overlay, separate timer so flicker + blackout can overlap visually.
    private func restartGhostBlackoutAction(for env: EnvironmentState) {
        blackoutOverlay.removeAllActions()
        guard env == .ghostMall else {
            blackoutOverlay.alpha = 0
            return
        }
        let dur = EnvironmentTuning.ghostMallBlackoutDuration
        let cadence = EnvironmentTuning.ghostMallBlackoutCadence
        let fadeIn = SKAction.fadeAlpha(to: 0.85, duration: dur / 2)
        let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: dur / 2)
        let wait = SKAction.wait(forDuration: cadence)
        blackoutOverlay.run(SKAction.repeatForever(
            SKAction.sequence([fadeIn, fadeOut, wait])
        ))
    }

    // Rebuild the procedural decay texture for (state, age tier). Cached
    // via lastEnvironmentState + lastDecayAgeTier — regenerated only when
    // either changes.
    private func rebuildDecayLayer(state env: EnvironmentState, ageTier: Int) {
        decayLayer.removeAllChildren()
        let intensity = decayIntensity(for: env)
        guard intensity > 0.0 else { return }
        // Scale intensity by age tier: a year-15 struggling mall reads
        // meaningfully more worn than year-3 struggling. Capped so late-game
        // doesn't blow out the overlay completely.
        let ageBoost = min(Double(ageTier) * 0.08, 0.4)
        let finalIntensity = min(0.85, intensity + ageBoost)

        if let texture = TextureFactory.decayTexture(
            env: env, ageTier: ageTier, intensity: finalIntensity,
            size: CGSize(width: GameConstants.worldWidth,
                         height: GameConstants.worldHeight)
        ) {
            let sprite = SKSpriteNode(texture: texture)
            // World coords are CSS (y-down); csToScene flips to SpriteKit y-up.
            // Anchor at (0,0) so the sprite's bottom-left aligns with the
            // scene's bottom-left after csToScene(0, worldHeight).
            let pos = csToScene(x: GameConstants.worldWidth / 2,
                                y: GameConstants.worldHeight / 2)
            sprite.position = pos
            sprite.alpha = 1.0
            decayLayer.addChild(sprite)
        }
    }

    private func decayIntensity(for env: EnvironmentState) -> Double {
        switch env {
        case .thriving:   return 0.0
        case .fading:     return 0.08
        case .struggling: return 0.18
        case .dying:      return 0.32
        case .dead:       return 0.48
        case .ghostMall:  return 0.55
        }
    }

    // Vignette visibility tracks whether corridor visitors have dropped
    // below the isolation threshold. Per-visitor shadow elongation + desat
    // are applied inside the visitor render sync (inside update()).
    //
    // Suppressed until didSeedVisitors flips true. Without the gate, the
    // very first reconcile fires BEFORE the scene's initial seed of 12
    // visitors runs in update(), so visitors.count == 0 → isolation active
    // → vignette fades in for a second, then fades out once the seed
    // populates. That brief dark pulse reads as an inexplicable flash on
    // fresh-run startup.
    private func reconcileIsolationVignette() {
        guard didSeedVisitors else {
            vignetteOverlay.removeAction(forKey: "vignetteFade")
            vignetteOverlay.alpha = 0
            return
        }
        let corridorCount = visitors.filter { v -> Bool in
            let phase = visitorBehavior[v.id]?.phase ?? .arriving
            if case .insideStore = phase { return false }
            return true
        }.count
        let isolated = corridorCount < EnvironmentTuning.isolationThreshold
        let targetAlpha: CGFloat = isolated ? 1.0 : 0.0
        // Smooth fade so vignette doesn't pop in/out as visitors spawn/despawn.
        if abs(vignetteOverlay.alpha - targetAlpha) > 0.01 {
            vignetteOverlay.removeAction(forKey: "vignetteFade")
            vignetteOverlay.run(
                SKAction.fadeAlpha(to: targetAlpha, duration: 1.2),
                withKey: "vignetteFade"
            )
        }
    }
}

