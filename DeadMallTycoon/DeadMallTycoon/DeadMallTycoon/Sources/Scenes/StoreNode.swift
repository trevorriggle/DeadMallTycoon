import SpriteKit

// v8: a single `.storefront` div with child `.sf-sign` and `.sf-window`.
// Tier color comes from the outer texture; sign label sits on top; window is a
// smaller pane (lit or dark). For vacant boarded stores, v8 draws a gate pattern.
final class StoreNode: SKSpriteNode {

    let storeId: Int
    private var signLabel: SKLabelNode
    private var windowNode: SKSpriteNode
    private var gateNode: SKSpriteNode?

    init(store: Store) {
        self.storeId = store.id
        let size = CGSize(width: store.position.w, height: store.position.h)
        let state = Self.visualState(for: store)
        let texture = TextureFactory.storefrontTexture(tier: store.tier,
                                                        state: state, size: size)

        // sign strip — 92% wide, 14 tall, at top
        let signWidth = size.width * 0.92
        signLabel = SKLabelNode(fontNamed: "Courier-Bold")
        signLabel.fontSize = 13
        signLabel.verticalAlignmentMode = .center

        // window — 92% wide, fills remainder, starts below sign
        let windowWidth = size.width * 0.92
        let windowHeight = size.height - 14 - 6    // 14 sign + 6 spacing/margin
        windowNode = SKSpriteNode(color: Palette.windowLit,
                                   size: CGSize(width: windowWidth, height: windowHeight))

        super.init(texture: texture, color: .clear, size: size)
        name = "store:\(storeId)"
        isUserInteractionEnabled = false   // handled at scene level via hit-testing

        // signLabel positioned at top of store
        signLabel.position = CGPoint(x: 0, y: size.height/2 - 10)
        addChild(signLabel)

        windowNode.position = CGPoint(x: 0, y: signLabel.position.y - 14 - windowHeight/2 + 4)
        addChild(windowNode)

        apply(store: store)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(store: Store) {
        let visual = Self.visualState(for: store)
        texture = TextureFactory.storefrontTexture(tier: store.tier,
                                                    state: visual, size: size)

        // Sign text
        if store.tier == .vacant {
            signLabel.text = store.monthsVacant >= 18 ? "" : store.monthsVacant >= 6 ? "CLOSED" : ""
            signLabel.fontColor = visual == .boarded ? Palette.signVacantFg : Palette.signVacantFg
        } else {
            signLabel.text = store.name.uppercased()
            signLabel.fontColor = Palette.signDark
        }
        // Sign bg — use a thin rect behind the label for non-vacant stores
        // (v8 draws a cream rectangle under the text). We tint signLabel background
        // via a separate SKShapeNode later if needed. For now the label sits on top
        // of the storefront fill, which reads close enough.

        // Window fill
        switch store.tier {
        case .vacant:
            windowNode.color = Palette.windowDark
        default:
            windowNode.color = Palette.windowLit
        }

        // Gate for recently-vacated (monthsVacant < 6)
        gateNode?.removeFromParent(); gateNode = nil
        if store.tier == .vacant && store.monthsVacant < 6 && store.monthsVacant > 0 {
            let gate = SKSpriteNode(color: Palette.gateDark,
                                     size: windowNode.size)
            gate.position = windowNode.position
            gate.alpha = 0.9
            addChild(gate)
            gateNode = gate
        }

        // Closing animation (pulsing border)
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
        if store.monthsVacant >= 18 { return .longAbandoned }
        if store.monthsVacant >= 6  { return .boarded }
        return .open
    }
}
