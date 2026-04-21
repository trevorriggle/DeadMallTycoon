import SpriteKit

// v8: .decoration with per-kind classes (kugel / fountain / plant / neon /
// bench / directory). Animations: kugel spins, neon flickers, hazards pulse.
// v9 Prompt 3 — unified sprite node for Artifact. Replaces the deleted
// DecorationNode. Renders the six legacy decoration kinds with their
// existing procedural textures; everything else (20 new Prompt 3 types +
// ambient types that happen to have a corridor position) falls back to the
// neutral "pending art" placeholder — a small grey square with a dotted
// outline, per the spec. Tap-to-inspect surfaces type identity in the info
// card; the sprite itself intentionally stays silent.
final class ArtifactNode: SKSpriteNode {

    let artifactId: Int
    private let artifactType: ArtifactType
    private var badgeNode: SKLabelNode?
    private var hazardDot: SKShapeNode?

    init(artifact: Artifact) {
        self.artifactId = artifact.id
        self.artifactType = artifact.type
        let size = ArtifactCatalog.info(artifact.type).size
        super.init(texture: Self.texture(for: artifact), color: .clear, size: size)
        name = "artifact:\(artifact.id)"
        isUserInteractionEnabled = false
        apply(artifact: artifact)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(artifact a: Artifact) {
        texture = Self.texture(for: a)
        updateAnimations(for: a)
        updateBadge(for: a)
        updateHazardDot(a.hazard)
    }

    // v9 Prompt 3 — per-type texture routing. The six legacy kinds keep their
    // v8 procedural textures. Every other ArtifactType (new Prompt 3 roster +
    // ambient) falls back to the pending-art placeholder. Real pixel art gets
    // swapped in one `case .<type>:` branch at a time later.
    private static func texture(for a: Artifact) -> SKTexture {
        let info = ArtifactCatalog.info(a.type)
        switch a.type {
        case .kugelBall:
            return TextureFactory.kugelTexture()
        case .fountain:
            return TextureFactory.fountainTexture(working: a.working && a.condition < 4)
        case .planter:
            return TextureFactory.plantTexture(dead: a.condition >= 3)
        case .neonSign:
            return TextureFactory.neonTexture(lit: a.working && a.condition < 4)
        case .bench:
            return TextureFactory.benchTexture()
        case .directoryBoard:
            return TextureFactory.directoryTexture()
        default:
            return TextureFactory.pendingArtPlaceholderTexture(size: info.size)
        }
    }

    private func updateAnimations(for a: Artifact) {
        // Kugel spins when working and not ruined.
        if a.type == .kugelBall && a.working && a.condition < 4 {
            if action(forKey: "spin") == nil {
                let spin = SKAction.rotate(byAngle: .pi * 2, duration: 15.0)
                run(SKAction.repeatForever(spin), withKey: "spin")
            }
        } else {
            removeAction(forKey: "spin")
            zRotation = 0
        }

        // Neon flicker when damaged but still lit.
        if a.type == .neonSign && a.working && a.condition >= 2 && a.condition < 4 {
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

        // Hazard pulse (secondary motion; the ambient hazard dot below is the
        // canonical at-a-glance indicator per the UI overhaul spec).
        if a.hazard {
            if action(forKey: "hazard") == nil {
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.08, duration: 0.75),
                    SKAction.scale(to: 1.00, duration: 0.75),
                ])
                run(SKAction.repeatForever(pulse), withKey: "hazard")
            }
        } else {
            removeAction(forKey: "hazard")
            setScale(1.0)
        }
        colorBlendFactor = 0
    }

    // v8: ambient hazard indicator — pulsing red dot top-right.
    private func updateHazardDot(_ hazard: Bool) {
        if hazard {
            if hazardDot == nil {
                let dot = SKShapeNode(circleOfRadius: 4)
                dot.fillColor = SKColor(red: 0.89, green: 0.29, blue: 0.29, alpha: 1.0)
                dot.strokeColor = SKColor.black.withAlphaComponent(0.8)
                dot.lineWidth = 1
                dot.position = CGPoint(x: size.width / 2 + 3, y: size.height / 2 + 3)
                dot.zPosition = 60
                let pulse = SKAction.repeatForever(SKAction.sequence([
                    SKAction.scale(to: 1.4, duration: 0.4),
                    SKAction.scale(to: 1.0, duration: 0.4),
                ]))
                dot.run(pulse)
                addChild(dot)
                hazardDot = dot
            }
        } else {
            hazardDot?.removeFromParent()
            hazardDot = nil
        }
    }

    private func updateBadge(for a: Artifact) {
        // Badge appears at condition>=3; shows "!" on hazards, condition name otherwise.
        if a.condition >= 3 {
            if badgeNode == nil {
                let label = SKLabelNode(fontNamed: "Courier-Bold")
                label.fontSize = 12
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.position = CGPoint(x: size.width / 2 + 4, y: size.height / 2 - 4)
                addChild(label)
                badgeNode = label
            }
            if a.hazard {
                badgeNode?.text = "!"
                badgeNode?.fontColor = UIColor(hex: "#e8e8f0")
            } else {
                badgeNode?.text = Condition(rawValue: a.condition)?.name ?? ""
                badgeNode?.fontColor = UIColor(hex: "#7fd3f0")
            }
        } else {
            badgeNode?.removeFromParent()
            badgeNode = nil
        }
    }
}
