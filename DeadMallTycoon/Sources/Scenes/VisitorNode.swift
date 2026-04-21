import SpriteKit

// v8: .visitor, with a small body composed of head + torso.
// Thought bubbles are a separate child created on tap and auto-dismissed.
// Bag indicator (Phase 3): a small tier-tinted rectangle next to the body,
// shown when the visitor recently exited a store — color encodes which tier
// (anchor bag looks different from kiosk bag).
final class VisitorNode: SKSpriteNode {

    let visitorId: UUID
    private var bagNode: SKShapeNode?

    init(visitor: Visitor) {
        self.visitorId = visitor.id
        let body = UIColor(hex: visitor.color)
        let head = UIColor(hex: visitor.headColor)
        let texture = TextureFactory.visitorTexture(bodyColor: body, headColor: head)
        super.init(texture: texture, color: .clear, size: CGSize(width: 26, height: 36))
        name = "visitor:\(visitor.id.uuidString)"
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func markSelected(_ selected: Bool) {
        if selected {
            if action(forKey: "selected") == nil {
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.4, duration: 0.5),
                    SKAction.scale(to: 1.2, duration: 0.5),
                ])
                run(SKAction.repeatForever(pulse), withKey: "selected")
            }
        } else {
            removeAction(forKey: "selected")
            setScale(1.0)
        }
    }

    // Phase 3 — bag indicator. nil tier removes the bag; otherwise creates or
    // retints a small rect next to the visitor's torso. Shape is shared across
    // tiers; color encodes tier (anchor tan, standard pink, kiosk blue, sketchy olive).
    func setBag(tier: StoreTier?) {
        guard let tier = tier, tier != .vacant else {
            bagNode?.removeFromParent()
            bagNode = nil
            return
        }
        if bagNode == nil {
            let bag = SKShapeNode(rectOf: CGSize(width: 8, height: 10), cornerRadius: 1)
            bag.strokeColor = UIColor.black.withAlphaComponent(0.6)
            bag.lineWidth = 1
            // Positioned beside the torso (node size is 26×36, origin centered).
            // Torso sits in the lower half of the texture; place bag at the right side.
            bag.position = CGPoint(x: 14, y: -6)
            bag.zPosition = 1
            addChild(bag)
            bagNode = bag
        }
        bagNode?.fillColor = Self.bagColor(for: tier)
    }

    private static func bagColor(for tier: StoreTier) -> UIColor {
        switch tier {
        case .anchor:   return Palette.storeAnchor
        case .standard: return Palette.storeStandard
        case .kiosk:    return Palette.storeKiosk
        case .sketchy:  return Palette.storeSketchy
        case .vacant:   return .gray  // unreachable — guarded above
        }
    }
}

// Pop-up thought bubble node — mimics v8 .thought-bubble.
// White rounded rect with italic text; lives 5 seconds then fades.
final class ThoughtBubbleNode: SKNode {

    init(text: String, maxWidth: CGFloat = 220) {
        super.init()
        let label = SKLabelNode(fontNamed: "Georgia-Italic")
        label.text = text
        label.fontSize = 15
        label.fontColor = Palette.bubbleText
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = maxWidth
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        // Size bubble to label's natural size with padding
        let naturalFrame = label.calculateAccumulatedFrame()
        let padX: CGFloat = 10
        let padY: CGFloat = 6
        let bubbleSize = CGSize(width: max(60, naturalFrame.width + padX * 2),
                                 height: max(24, naturalFrame.height + padY * 2))

        let bg = SKShapeNode(rectOf: bubbleSize, cornerRadius: 8)
        bg.fillColor = Palette.bubbleBg
        bg.strokeColor = Palette.bubbleBorder
        bg.lineWidth = 2
        addChild(bg)
        addChild(label)

        // Ambient fade-in, then auto fade-out after 5s (matches v8 setTimeout 5000).
        alpha = 0
        let pop = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.3),
            SKAction.wait(forDuration: 5.0),
            SKAction.fadeAlpha(to: 0, duration: 0.5),
            SKAction.removeFromParent(),
        ])
        run(pop)
    }

    required init?(coder: NSCoder) { fatalError() }
}
