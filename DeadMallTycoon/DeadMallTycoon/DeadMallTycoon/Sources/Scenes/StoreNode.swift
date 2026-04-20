import SpriteKit

// v8: a single `.storefront` div with child `.sf-sign` and `.sf-window`.
// Placeholder art (Open.png / Closed.png from Assets.xcassets) stands in for
// Christian's final 128x128 pixel art — the PNG bakes in sign + window + frame,
// so the procedural sign/window/gate overlays from earlier phases are retired.
//
// Ambient indicators (Phase C UI overhaul):
// - Stores about to close: yellow pulsing dot in the top-right of the storefront.
//   Replaces the old full-sprite red colorize pulse — that tint competed with the
//   pixel art and wasn't a clear at-a-glance signal.
final class StoreNode: SKSpriteNode {

    let storeId: Int
    private var closingDot: SKShapeNode?

    init(store: Store) {
        self.storeId = store.id
        let size = CGSize(width: store.position.w, height: store.position.h)
        let texture = TextureFactory.storefrontTexture(tier: store.tier,
                                                        state: Self.visualState(for: store))

        super.init(texture: texture, color: .clear, size: size)
        name = "store:\(storeId)"
        isUserInteractionEnabled = false

        apply(store: store)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(store: Store) {
        let visual = Self.visualState(for: store)
        texture = TextureFactory.storefrontTexture(tier: store.tier, state: visual)

        updateClosingDot(store.closing)
        updatePromoGlow(store.promotionActive)
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

    static func visualState(for store: Store) -> StorefrontVisualState {
        if store.tier != .vacant { return .open }
        if store.monthsVacant >= 6 { return .boarded }
        return .open
    }
}
