import SpriteKit

// v8: a single `.storefront` div with child `.sf-sign` and `.sf-window`.
// Placeholder art (Open.png / Closed.png from Assets.xcassets) stands in for
// Christian's final 128x128 pixel art — the PNG bakes in sign + window + frame,
// so the procedural sign/window/gate overlays from earlier phases are retired.
//
// Anchor slots (Halvorsen west, Pemberton east) are full-height end-caps and use a
// procedural facade + SKLabelNode signage instead of the stretched pixel-art PNG.
// An anchor slot is detected by footprint width (>= 180pt) — see StartingMall
// positions for the 200pt anchor width.
//
// Ambient indicators (Phase C UI overhaul):
// - Stores about to close: yellow pulsing dot in the top-right of the storefront.
//   Replaces the old full-sprite red colorize pulse — that tint competed with the
//   pixel art and wasn't a clear at-a-glance signal.
final class StoreNode: SKSpriteNode {

    let storeId: Int
    private let isAnchorSlot: Bool
    private var closingDot: SKShapeNode?
    private var anchorNameLabel: SKLabelNode?
    // v9 Prompt 10 Phase C — permanent darkening layer on a vacant anchor.
    // Sits above the base .boarded facade texture but below ambient
    // indicators (closing dot / promo glow). Present only when the anchor
    // has actually departed; adding/removing this layer is driven by
    // apply(store:) so a re-tenant (not currently possible, but defensive)
    // would clear it.
    private var deadEndDimmer: SKSpriteNode?

    init(store: Store) {
        self.storeId = store.id
        self.isAnchorSlot = store.position.w >= 180
        let size = CGSize(width: store.position.w, height: store.position.h)
        let visual = Self.visualState(for: store)
        let texture: SKTexture = isAnchorSlot
            ? TextureFactory.anchorFacadeTexture(state: visual, size: size)
            : TextureFactory.storefrontTexture(tier: store.tier, state: visual)

        super.init(texture: texture, color: .clear, size: size)
        name = "store:\(storeId)"
        isUserInteractionEnabled = false

        if isAnchorSlot {
            // Signage label sits on the dark band baked into the facade texture.
            // Positioned in the node's local coord space (origin at center, y-up).
            let label = SKLabelNode(fontNamed: "Courier-Bold")
            label.fontSize = 22
            label.fontColor = Palette.signLight
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            // Signage band is 30..100pt from the top of the texture; center ≈ 65pt from top.
            label.position = CGPoint(x: 0, y: size.height / 2 - 65)
            label.zPosition = 1
            label.name = "anchorName"
            addChild(label)
            anchorNameLabel = label
        }

        apply(store: store)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(store: Store) {
        let visual = Self.visualState(for: store)
        texture = isAnchorSlot
            ? TextureFactory.anchorFacadeTexture(state: visual, size: size)
            : TextureFactory.storefrontTexture(tier: store.tier, state: visual)

        if isAnchorSlot {
            // Vacant anchor shows as a dark gap — the "huge empty space" emotional beat.
            // Hide the name label entirely when vacant so the void reads clean.
            anchorNameLabel?.text = store.isVacant ? "" : store.name.uppercased()
            anchorNameLabel?.isHidden = store.isVacant
            updateDeadEndDimmer(vacant: store.isVacant)
        }

        updateClosingDot(store.closing)
        updatePromoGlow(store.promotionActive)
    }

    // v9 Prompt 10 Phase C — permanent darkening on a vacant anchor.
    // The .boarded facade texture already bakes in the boarded-door look
    // and the signage label is hidden separately above. This layer adds
    // the extra "this side of the mall has gone dark" weight so a vacant
    // anchor reads as a dead end, not just a closed store.
    private func updateDeadEndDimmer(vacant: Bool) {
        if vacant {
            if deadEndDimmer == nil {
                let dim = SKSpriteNode(
                    color: SKColor.black.withAlphaComponent(0.45),
                    size: size)
                dim.zPosition = 10   // above base texture (0), below closing dot (50)
                dim.name = "deadEndDimmer"
                addChild(dim)
                deadEndDimmer = dim
            }
        } else {
            deadEndDimmer?.removeFromParent()
            deadEndDimmer = nil
        }
    }

    // MARK: - Ambient indicators

    private func updateClosingDot(_ closing: Bool) {
        if closing {
            if closingDot == nil {
                let dot = SKShapeNode(circleOfRadius: 5)
                dot.fillColor = SKColor(red: 0.98, green: 0.78, blue: 0.16, alpha: 1.0)  // yellow
                dot.strokeColor = SKColor.black.withAlphaComponent(0.8)
                dot.lineWidth = 1
                dot.position = CGPoint(x: size.width / 2 - 9, y: size.height / 2 - 9)
                dot.zPosition = 50
                let pulse = SKAction.repeatForever(SKAction.sequence([
                    SKAction.scale(to: 1.35, duration: 0.45),
                    SKAction.scale(to: 1.00, duration: 0.45),
                ]))
                dot.run(pulse)
                addChild(dot)
                closingDot = dot
            }
        } else {
            closingDot?.removeFromParent()
            closingDot = nil
        }
    }

    private func updatePromoGlow(_ active: Bool) {
        if active {
            if childNode(withName: "promoGlow") == nil {
                let glow = SKShapeNode(rectOf: size, cornerRadius: 2)
                glow.strokeColor = Palette.threatWarn
                glow.lineWidth = 3
                glow.glowWidth = 6
                glow.fillColor = .clear
                glow.name = "promoGlow"
                addChild(glow)
            }
        } else {
            childNode(withName: "promoGlow")?.removeFromParent()
        }
    }

    // v9 Prompt 2: any vacant slot shows Closed.png immediately. Previously
    // gated behind `monthsVacant >= 6`, which meant a freshly-evicted slot
    // kept the Open.png texture for six months — visually misleading.
    // The artifact data layer still tracks closure history in state.artifacts
    // for future scoring + thought-bubble prompts; the slot sprite itself is
    // now the visual signal.
    static func visualState(for store: Store) -> StorefrontVisualState {
        store.tier == .vacant ? .boarded : .open
    }
}
