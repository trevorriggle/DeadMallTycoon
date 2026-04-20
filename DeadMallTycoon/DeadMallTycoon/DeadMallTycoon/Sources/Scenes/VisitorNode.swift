import SpriteKit

// v8: .visitor, with a small body composed of head + torso.
// Thought bubbles are a separate child created on tap and auto-dismissed.
final class VisitorNode: SKSpriteNode {

    let visitorId: UUID

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
