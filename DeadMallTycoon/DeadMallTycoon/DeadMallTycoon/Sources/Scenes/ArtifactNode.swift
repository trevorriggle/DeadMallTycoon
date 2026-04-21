import SpriteKit

// v9: Scene-level overlay for a single Artifact. Prompt 2 supports only
// boardedStorefront artifacts (overlay on top of a storefront sprite). Future
// prompts add ambient types (stoppedFountain, waterStainedCeiling, etc.)
// which will extend this node with a type-dispatched render path.
final class ArtifactNode: SKSpriteNode {

    let artifactId: Int
    let artifactType: ArtifactType

    init(artifact: Artifact, size: CGSize) {
        self.artifactId = artifact.id
        self.artifactType = artifact.type

        // Prompt 2: only boardedStorefront is wired to a texture. Other types
        // fall through to a clear sprite — they're not yet created by any
        // mechanic, so this path is unreachable in Prompt 2 but prevents a
        // crash if a later prompt drops in before the texture is added.
        let texture: SKTexture? = {
            switch artifact.type {
            case .boardedStorefront:
                return TextureFactory.boardedStorefrontOverlayTexture(size: size)
            default:
                return nil
            }
        }()

        super.init(texture: texture, color: .clear, size: size)
        name = "artifact:\(artifact.id)"
        isUserInteractionEnabled = false
        // Nearest-neighbor filtering so the procedural pixel art stays crisp
        // when the SKView is scaled (matches storefront texture behavior).
        texture?.filteringMode = .nearest

        // DIAG (Prompt 2 verification) — remove once overlay rendering is
        // confirmed end-to-end.
        print("[ARTIFACT] ArtifactNode init id=\(artifact.id) type=\(artifact.type) size=\(size) hasTexture=\(texture != nil)")
    }

    required init?(coder: NSCoder) { fatalError() }
}
