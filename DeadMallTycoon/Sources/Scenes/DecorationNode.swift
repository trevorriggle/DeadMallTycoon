import SpriteKit

// v8: .decoration with per-kind classes (kugel / fountain / plant / neon / bench / directory).
// Animations: kugel spins, neon flickers, hazards glow/pulse.
final class DecorationNode: SKSpriteNode {

    let decorationId: Int
    private let kind: DecorationKind
    private var badgeNode: SKLabelNode?

    init(decoration: Decoration) {
        self.decorationId = decoration.id
        self.kind = decoration.kind
        let size = DecorationTypes.type(decoration.kind).size
        super.init(texture: Self.texture(for: decoration), color: .clear, size: size)
        name = "decoration:\(decorationId)"
        isUserInteractionEnabled = false
        apply(decoration: decoration)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(decoration d: Decoration) {
        texture = Self.texture(for: d)
        updateAnimations(for: d)
        updateBadge(for: d)
    }

    private static func texture(for d: Decoration) -> SKTexture {
        switch d.kind {
        case .kugel:     return TextureFactory.kugelTexture()
        case .fountain:  return TextureFactory.fountainTexture(working: d.working && d.condition < 4)
        case .plant:     return TextureFactory.plantTexture(dead: d.condition >= 3)
        case .neon:      return TextureFactory.neonTexture(lit: d.working && d.condition < 4)
        case .bench:     return TextureFactory.benchTexture()
        case .directory: return TextureFactory.directoryTexture()
        }
    }

    private func updateAnimations(for d: Decoration) {
        // Spin kugel when working and not ruined
        if d.kind == .kugel && d.working && d.condition < 4 {
            if action(forKey: "spin") == nil {
                let spin = SKAction.rotate(byAngle: .pi * 2, duration: 15.0)
                run(SKAction.repeatForever(spin), withKey: "spin")
            }
        } else {
            removeAction(forKey: "spin")
            zRotation = 0
        }

        // Neon flicker when damaged but still lit
        if d.kind == .neon && d.working && d.condition >= 2 && d.condition < 4 {
            if action(forKey: "flicker") == nil {
                let flicker = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.4, duration: 0.15),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.15),
                ])
                run(SKAction.repeatForever(flicker), withKey: "flicker")
            }
        } else {
            removeAction(forKey: "flicker")
            alpha = 1.0
        }

        // Hazard glow/pulse (red drop-shadow simulation)
        if d.hazard {
            if action(forKey: "hazard") == nil {
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.08, duration: 0.75),
                    SKAction.scale(to: 1.00, duration: 0.75),
                ])
                run(SKAction.repeatForever(pulse), withKey: "hazard")
            }
            colorBlendFactor = 0.3
            color = Palette.threatDanger
        } else {
            removeAction(forKey: "hazard")
            setScale(1.0)
            colorBlendFactor = 0
        }
    }

    private func updateBadge(for d: Decoration) {
        // v8 shows a condition badge when condition>=3, and a red "!" badge on hazards.
        if d.condition >= 3 {
            if badgeNode == nil {
                let label = SKLabelNode(fontNamed: "Courier-Bold")
                label.fontSize = 12
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.position = CGPoint(x: size.width / 2 + 4, y: size.height / 2 - 4)
                addChild(label)
                badgeNode = label
            }
            if d.hazard {
                badgeNode?.text = "!"
                badgeNode?.fontColor = UIColor(hex: "#fcebeb")
            } else {
                badgeNode?.text = Condition(rawValue: d.condition)?.name ?? ""
                badgeNode?.fontColor = UIColor(hex: "#fac775")
            }
        } else {
            badgeNode?.removeFromParent()
            badgeNode = nil
        }
    }
}
