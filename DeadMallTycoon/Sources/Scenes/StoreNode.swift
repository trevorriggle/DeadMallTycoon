import SpriteKit

// v8: a single `.storefront` div with child `.sf-sign` and `.sf-window`.
// Placeholder art (Open.png / Closed.png from Assets.xcassets) stands in for
// Christian's final 128x128 pixel art — the PNG bakes in sign + window + frame,
// so the procedural sign/window/gate overlays from earlier phases are retired.
// When final art lands, swap the imageNamed string in `storefrontTexture` below.
final class StoreNode: SKSpriteNode {

    let storeId: Int

    init(store: Store) {
        self.storeId = store.id
        let size = CGSize(width: store.position.w, height: store.position.h)
        let texture = TextureFactory.storefrontTexture(tier: store.tier,
                                                        state: Self.visualState(for: store))

        super.init(texture: texture, color: .clear, size: size)
        name = "store:\(storeId)"
        isUserInteractionEnabled = false   // handled at scene level via hit-testing

        apply(store: store)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(store: Store) {
        let visual = Self.visualState(for: store)
        texture = TextureFactory.storefrontTexture(tier: store.tier, state: visual)

        // Closing animation (pulsing danger tint)
        if store.closing {
            if action(forKey: "closing") == nil {
                let pulse = SKAction.sequence([
                    SKAction.colorize(with: Palette.threatDanger, colorBlendFactor: 0.4, duration: 0.65),
                    SKAction.colorize(with: .clear, colorBlendFactor: 0, duration: 0.65),
                ])
                run(SKAction.repeatForever(pulse), withKey: "closing")
            }
        } else {
            removeAction(forKey: "closing")
            colorBlendFactor = 0
        }

        // Promotion glow
        if store.promotionActive {
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
        if store.monthsVacant >= 6 { return .boarded }   // boarded + longAbandoned both render Closed.png
        return .open
    }
}
