import UIKit
import SpriteKit
import CoreGraphics

// Procedural textures that reproduce v8's CSS backgrounds:
// - radial-gradient dot patterns on the corridor floor
// - subtle grid on ceiling strips
// - diagonal stripe on sealed wings
// - radial gradient fills for kugel / fountain / plant / neon / directory
//
// This is how we "generate assets as similar as possible" without shipping bitmaps —
// when Christian's 128x128 pixel art lands later, we swap the SKTexture source one line
// per node type.
enum TextureFactory {

    // MARK: - Caches

    private static var cache: [String: SKTexture] = [:]

    private static func cached(_ key: String, _ build: () -> SKTexture) -> SKTexture {
        if let existing = cache[key] { return existing }
        let made = build()
        cache[key] = made
        return made
    }

    // MARK: - Floor

    // v8 floor: #c8bca0 base + three offset dot patterns at 30/40/50px tile sizes.
    // We compose a single 120×120 tile (LCM-ish) with representative dot placements.
    static func floorTile() -> SKTexture {
        cached("floor") {
            SKTexture(image: renderImage(size: CGSize(width: 120, height: 120)) { ctx, size in
                Palette.floor.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))

                let dots: [(UIColor, CGFloat, CGFloat, CGFloat, CGFloat)] = [
                    (Palette.floorDot1, 30, 0.15, 0.25, 0.9),
                    (Palette.floorDot1, 30, 0.15 + 0.5, 0.25 + 0.3, 0.9),
                    (Palette.floorDot2, 40, 0.65, 0.55, 0.9),
                    (Palette.floorDot2, 40, 0.65 - 0.5, 0.55 + 0.3, 0.9),
                    (Palette.floorDot3, 50, 0.35, 0.75, 0.9),
                    (Palette.floorDot3, 50, 0.35 + 0.3, 0.75 - 0.5, 0.9),
                ]
                for (color, tile, tx, ty, radius) in dots {
                    color.setFill()
                    var y: CGFloat = ty.truncatingRemainder(dividingBy: 1) * tile
                    while y < size.height + tile {
                        var x: CGFloat = tx.truncatingRemainder(dividingBy: 1) * tile
                        while x < size.width + tile {
                            let dot = CGRect(x: x - radius, y: y - radius,
                                              width: radius * 2, height: radius * 2)
                            ctx.fillEllipse(in: dot)
                            x += tile
                        }
                        y += tile
                    }
                }
            })
        }
    }

    // v8 ceiling / dead-zone background: #2a2520 with a 30x30 faint grid.
    static func ceilingTile() -> SKTexture {
        cached("ceiling") {
            SKTexture(image: renderImage(size: CGSize(width: 30, height: 30)) { ctx, size in
                Palette.ceilingBg.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                UIColor(white: 1, alpha: 0.03).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: 1))
                ctx.fill(CGRect(x: 0, y: 0, width: 1, height: size.height))
            })
        }
    }

    // v8 wing-sealed overlay: diagonal 45deg stripes alternating two browns.
    static func wingSealedTile() -> SKTexture {
        cached("wingSealed") {
            SKTexture(image: renderImage(size: CGSize(width: 40, height: 40)) { ctx, size in
                Palette.wingSealedA.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                Palette.wingSealedB.setFill()
                // draw diagonal stripes 10px wide spaced every 20px
                ctx.saveGState()
                ctx.translateBy(x: size.width / 2, y: size.height / 2)
                ctx.rotate(by: .pi / 4)
                ctx.translateBy(x: -size.width, y: -size.height)
                var x: CGFloat = 0
                while x < size.width * 2 {
                    ctx.fill(CGRect(x: x, y: 0, width: 10, height: size.height * 2))
                    x += 20
                }
                ctx.restoreGState()
            })
        }
    }

    // MARK: - Decorations

    // Kugel ball — radial gradient circle (light top-left → dark)
    static func kugelTexture() -> SKTexture {
        cached("kugel") {
            SKTexture(image: renderImage(size: CGSize(width: 32, height: 32)) { ctx, size in
                drawRadialCircle(ctx: ctx, rect: CGRect(origin: .zero, size: size),
                                 highlightOffset: CGPoint(x: -6, y: -6),
                                 hi: Palette.kugelHi, lo: Palette.kugelLo)
                Palette.kugelBorder.setStroke()
                ctx.setLineWidth(2)
                ctx.strokeEllipse(in: CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2))
            })
        }
    }

    static func fountainTexture(working: Bool) -> SKTexture {
        cached(working ? "fountainWorking" : "fountainBroken") {
            SKTexture(image: renderImage(size: CGSize(width: 50, height: 50)) { ctx, size in
                drawRadialCircle(ctx: ctx, rect: CGRect(origin: .zero, size: size),
                                 highlightOffset: .zero,
                                 hi: working ? Palette.fountainHi : Palette.fountainBrokenHi,
                                 lo: working ? Palette.fountainLo : Palette.fountainBrokenLo)
                Palette.fountainBorder.setStroke()
                ctx.setLineWidth(3)
                ctx.strokeEllipse(in: CGRect(x: 1.5, y: 1.5, width: size.width - 3, height: size.height - 3))
            })
        }
    }

    static func plantTexture(dead: Bool) -> SKTexture {
        cached(dead ? "plantDead" : "plant") {
            SKTexture(image: renderImage(size: CGSize(width: 22, height: 22)) { ctx, size in
                drawRadialCircle(ctx: ctx, rect: CGRect(origin: .zero, size: size),
                                 highlightOffset: .zero,
                                 hi: dead ? Palette.plantDeadHi : Palette.plantHi,
                                 lo: dead ? Palette.plantDeadLo : Palette.plantLo)
                Palette.plantBorder.setStroke()
                ctx.setLineWidth(2)
                ctx.strokeEllipse(in: CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2))
            })
        }
    }

    static func neonTexture(lit: Bool) -> SKTexture {
        cached(lit ? "neonLit" : "neonDark") {
            SKTexture(image: renderImage(size: CGSize(width: 40, height: 14)) { ctx, size in
                (lit ? Palette.neonFill : Palette.neonDark).setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                Palette.neonBorder.setStroke()
                ctx.setLineWidth(1)
                ctx.stroke(CGRect(x: 0.5, y: 0.5, width: size.width - 1, height: size.height - 1))
            })
        }
    }

    static func benchTexture() -> SKTexture {
        cached("bench") {
            SKTexture(image: renderImage(size: CGSize(width: 36, height: 10)) { ctx, size in
                Palette.benchFill.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                Palette.benchBorder.setStroke()
                ctx.setLineWidth(1)
                ctx.stroke(CGRect(x: 0.5, y: 0.5, width: size.width - 1, height: size.height - 1))
            })
        }
    }

    static func directoryTexture() -> SKTexture {
        cached("directory") {
            SKTexture(image: renderImage(size: CGSize(width: 22, height: 30)) { ctx, size in
                Palette.directoryFill.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                // inset glow — simulate box-shadow:inset 0 0 4px #fac775 with a thin glow ring
                let glow = Palette.directoryGlow.withAlphaComponent(0.5)
                glow.setStroke()
                ctx.setLineWidth(2)
                ctx.stroke(CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4))
                Palette.directoryBorder.setStroke()
                ctx.setLineWidth(2)
                ctx.stroke(CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2))
            })
        }
    }

    // MARK: - Storefront (placeholder art from Assets.xcassets)

    // Placeholder sprites from Christian's temporary 128x128 pixel art.
    // Open.png → any operating tier (anchor/standard/kiosk/sketchy) and
    // freshly-vacated stores (< 6 months, still look "open" per v8).
    // Closed.png → boarded + long-abandoned vacant stores.
    // Tier-specific / state-specific art is a TODO for the final art pass.
    static func storefrontTexture(tier: StoreTier, state: StorefrontVisualState) -> SKTexture {
        let imageName: String
        switch state {
        case .boarded, .longAbandoned: imageName = "Closed"
        case .open:                    imageName = "Open"
        }
        return cached("store_image_\(imageName)") {
            let tex = SKTexture(imageNamed: imageName)
            tex.filteringMode = .nearest   // pixel art — no smoothing when stretched
            return tex
        }
    }

    // Anchor end-cap facade — procedural, no v8 equivalent (v8 treated anchors as
    // standard slots). Drawn in scene CSS units; y=0 is the top of the scene so the
    // signage band lives at the top, entrance archway at the bottom-center.
    // StoreNode layers the store name as a SKLabelNode on top of the signage band.
    static func anchorFacadeTexture(state: StorefrontVisualState, size: CGSize) -> SKTexture {
        let stateKey: String = {
            switch state {
            case .open:          return "open"
            case .boarded:       return "boarded"
            case .longAbandoned: return "abandoned"
            }
        }()
        let key = "anchorFacade_\(stateKey)_\(Int(size.width))x\(Int(size.height))"
        return cached(key) {
            SKTexture(image: renderImage(size: size) { ctx, size in
                switch state {
                case .open:
                    // Warm tan facade with darker border + sign band + central archway.
                    Palette.storeAnchor.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))

                    // Outer border (thick — reads as a substantial building).
                    Palette.storeAnchorBorder.setStroke()
                    ctx.setLineWidth(4)
                    ctx.stroke(CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4))

                    // Signage band near top — dark panel where the store name label sits.
                    let signHeight: CGFloat = 70
                    let signRect = CGRect(x: 10, y: 30, width: size.width - 20, height: signHeight)
                    Palette.signDark.setFill()
                    ctx.fill(signRect)
                    Palette.storeAnchorBorder.setStroke()
                    ctx.setLineWidth(2)
                    ctx.stroke(signRect)

                    // Window band — lit warm rectangles below the sign, above the archway.
                    let windowY: CGFloat = 130
                    let windowHeight: CGFloat = size.height - windowY - 140
                    let windowRect = CGRect(x: 20, y: windowY, width: size.width - 40, height: windowHeight)
                    Palette.windowLit.setFill()
                    ctx.fill(windowRect)
                    // Window frame divisions — three horizontal bands for that department-store look.
                    Palette.storeAnchorBorder.setStroke()
                    ctx.setLineWidth(2)
                    ctx.stroke(windowRect)
                    let bandStep = windowHeight / 3
                    for i in 1...2 {
                        let y = windowY + bandStep * CGFloat(i)
                        ctx.move(to: CGPoint(x: 20, y: y))
                        ctx.addLine(to: CGPoint(x: size.width - 20, y: y))
                        ctx.strokePath()
                    }

                    // Central entrance archway at the bottom — dark doorway.
                    let archWidth: CGFloat = min(120, size.width * 0.5)
                    let archHeight: CGFloat = 110
                    let archRect = CGRect(x: (size.width - archWidth) / 2,
                                          y: size.height - archHeight - 10,
                                          width: archWidth, height: archHeight)
                    Palette.gateDark.setFill()
                    ctx.fill(archRect)
                    Palette.storeAnchorBorder.setStroke()
                    ctx.setLineWidth(3)
                    ctx.stroke(archRect)

                case .boarded:
                    // Dark boarded facade — the "huge dark gap" emotional beat.
                    Palette.storeBoarded.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))
                    Palette.storeBoardedBorder.setStroke()
                    ctx.setLineWidth(4)
                    ctx.stroke(CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4))
                    // Plywood planks — horizontal darker stripes.
                    Palette.storeAbandoned.setFill()
                    let plankHeight: CGFloat = 18
                    var y: CGFloat = 40
                    while y < size.height - 20 {
                        ctx.fill(CGRect(x: 10, y: y, width: size.width - 20, height: plankHeight))
                        y += plankHeight + 12
                    }

                case .longAbandoned:
                    // Near-black void — the mall has lost its anchor for a long time.
                    Palette.storeAbandoned.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))
                    Palette.storeBoardedBorder.setStroke()
                    ctx.setLineWidth(3)
                    ctx.stroke(CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4))
                }
            })
        }
    }

    // MARK: - Visitor

    // Visitor body: scaled up ~2.6x from v8's 10x14 so visitors are actually tappable on iPad.
    // 26x36 with a 20x18 circle head and a 26x20 rounded-top torso.
    static func visitorTexture(bodyColor: UIColor, headColor: UIColor) -> SKTexture {
        let key = "visitor_\(bodyColor.hashValue)_\(headColor.hashValue)"
        return cached(key) {
            SKTexture(image: renderImage(size: CGSize(width: 26, height: 36)) { ctx, size in
                // head — 20x18 circle centered horizontally at top
                headColor.setFill()
                UIColor.black.withAlphaComponent(0.4).setStroke()
                ctx.setLineWidth(2)
                let head = CGRect(x: 3, y: 0, width: 20, height: 18)
                ctx.fillEllipse(in: head)
                ctx.strokeEllipse(in: head)
                // torso — rounded top
                bodyColor.setFill()
                let torso = CGRect(x: 0, y: 16, width: 26, height: 20)
                let path = UIBezierPath(roundedRect: torso,
                                        byRoundingCorners: [.topLeft, .topRight],
                                        cornerRadii: CGSize(width: 5, height: 5))
                ctx.addPath(path.cgPath)
                ctx.fillPath()
                ctx.addPath(path.cgPath)
                UIColor.black.withAlphaComponent(0.4).setStroke()
                ctx.strokePath()
            })
        }
    }

    // MARK: - Artifact placeholder (v9 Prompt 3)

    // v9 Prompt 3 — neutral "pending art" sprite for any ArtifactType that
    // doesn't have a specific pixel-art texture yet. Small grey square,
    // dotted outline, no text. Tap-to-inspect handles the identity question.
    // Trevor will swap in real per-type pixel art later; this single function
    // is the only thing that needs to change at that point.
    static func pendingArtPlaceholderTexture(size: CGSize) -> SKTexture {
        let key = "pendingArt_\(Int(size.width))x\(Int(size.height))"
        return cached(key) {
            SKTexture(image: renderImage(size: size) { ctx, size in
                // Fill — neutral mid-grey. Semi-transparent so existing corridor
                // floor tone shows through slightly and the placeholder doesn't
                // steamroll the mall's visual palette.
                UIColor(white: 0.45, alpha: 0.85).setFill()
                ctx.fill(CGRect(origin: .zero, size: size))

                // Dotted outline — draw a 1.5pt stroke with short dashes.
                UIColor(white: 0.2, alpha: 0.9).setStroke()
                ctx.setLineWidth(1.5)
                ctx.setLineDash(phase: 0, lengths: [3, 2])
                let inset: CGFloat = 1
                ctx.stroke(CGRect(origin: .zero, size: size)
                            .insetBy(dx: inset, dy: inset))
            })
        }
    }

    // MARK: - Helpers

    private static func renderImage(size: CGSize,
                                    draw: (CGContext, CGSize) -> Void) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { rendererCtx in
            let ctx = rendererCtx.cgContext
            draw(ctx, size)
        }
    }

    private static func drawRadialCircle(ctx: CGContext, rect: CGRect,
                                         highlightOffset: CGPoint,
                                         hi: UIColor, lo: UIColor) {
        let colors = [hi.cgColor, lo.cgColor] as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        guard let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else {
            hi.setFill(); ctx.fillEllipse(in: rect); return
        }
        ctx.saveGState()
        ctx.addEllipse(in: rect)
        ctx.clip()
        let center = CGPoint(x: rect.midX + highlightOffset.x,
                              y: rect.midY + highlightOffset.y)
        ctx.drawRadialGradient(grad,
                                startCenter: center, startRadius: 0,
                                endCenter: CGPoint(x: rect.midX, y: rect.midY),
                                endRadius: max(rect.width, rect.height) / 2,
                                options: [])
        ctx.restoreGState()
    }
}

enum StorefrontVisualState: String {
    case open, boarded, longAbandoned
}

// MARK: - v9 Prompt 8 — decay overlay

extension TextureFactory {

    /// Procedural decay overlay covering the H-shape walkable area (main
    /// corridor + upper/lower access corridors). Returns a full-scene-sized
    /// texture with decay patterns drawn only in walkable regions so store
    /// and anchor rects remain un-overlaid.
    ///
    /// Cached by `(env, ageTier, intensity)`. MallScene invalidates via
    /// `lastEnvironmentState` + `lastDecayAgeTier`, so the cache read only
    /// bypasses regeneration on same-state, same-tier re-renders.
    static func decayTexture(env: EnvironmentState,
                             ageTier: Int,
                             intensity: Double,
                             size: CGSize) -> SKTexture? {
        let key = "decay-\(env.rawValue)-t\(ageTier)-i\(Int(intensity * 1000))-s\(Int(size.width))x\(Int(size.height))"
        if let hit = cache[key] { return hit }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            let g = ctx.cgContext
            g.clear(CGRect(origin: .zero, size: size))

            // Deterministic RNG from key — same state + tier produces the
            // same layout, so transitions don't flicker the wear pattern.
            var rng = SeededGenerator(seed: UInt64(abs(key.hashValue)) | 1)

            // Walkable regions in CSS coords (y-down). Convert to image
            // coords (which are also y-down in UIGraphicsImageRenderer).
            let upperAccess = CGRect(x: 0, y: 110, width: size.width, height: 30)
            let lowerAccess = CGRect(x: 0, y: 380, width: size.width, height: 30)
            let mainCorridor = CGRect(x: 200, y: 140, width: size.width - 400, height: 240)
            let regions = [upperAccess, lowerAccess, mainCorridor]

            // Layer 1: mottling — small random dots across walkable.
            let dotCount = Int(600.0 * intensity)
            for _ in 0..<dotCount {
                guard let region = regions.randomElement(using: &rng) else { continue }
                let x = CGFloat.random(in: region.minX..<region.maxX, using: &rng)
                let y = CGFloat.random(in: region.minY..<region.maxY, using: &rng)
                let r = CGFloat.random(in: 0.6..<2.4, using: &rng)
                let alpha = CGFloat.random(in: 0.12..<0.35, using: &rng) * CGFloat(intensity)
                UIColor(white: 0.12, alpha: alpha).setFill()
                g.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }

            // Layer 2: scuff lines — short dark strokes.
            let scuffCount = Int(60.0 * intensity)
            for _ in 0..<scuffCount {
                guard let region = regions.randomElement(using: &rng) else { continue }
                let x = CGFloat.random(in: region.minX..<region.maxX, using: &rng)
                let y = CGFloat.random(in: region.minY..<region.maxY, using: &rng)
                let len = CGFloat.random(in: 6..<22, using: &rng)
                let angle = CGFloat.random(in: 0..<CGFloat.pi, using: &rng)
                let x2 = x + cos(angle) * len
                let y2 = y + sin(angle) * len
                g.setStrokeColor(UIColor(white: 0.08,
                                          alpha: 0.35 * CGFloat(intensity)).cgColor)
                g.setLineWidth(CGFloat.random(in: 0.7..<1.5, using: &rng))
                g.move(to: CGPoint(x: x, y: y))
                g.addLine(to: CGPoint(x: x2, y: y2))
                g.strokePath()
            }

            // Layer 3: water stains (dying+). Irregular translucent brown blobs.
            if intensity >= 0.30 {
                let stainCount = Int(14.0 * intensity)
                for _ in 0..<stainCount {
                    guard let region = regions.randomElement(using: &rng) else { continue }
                    let cx = CGFloat.random(in: region.minX..<region.maxX, using: &rng)
                    let cy = CGFloat.random(in: region.minY..<region.maxY, using: &rng)
                    let radius = CGFloat.random(in: 14..<36, using: &rng)
                    let stain = UIColor(red: 0.35, green: 0.28, blue: 0.18,
                                        alpha: 0.18 * CGFloat(intensity))
                    stain.setFill()
                    g.fillEllipse(in: CGRect(x: cx - radius, y: cy - radius,
                                              width: radius * 2, height: radius * 2))
                    // Darker core
                    let core = UIColor(red: 0.20, green: 0.15, blue: 0.10,
                                       alpha: 0.22 * CGFloat(intensity))
                    core.setFill()
                    let coreR = radius * 0.5
                    g.fillEllipse(in: CGRect(x: cx - coreR, y: cy - coreR,
                                              width: coreR * 2, height: coreR * 2))
                }
            }

            // Layer 4: cracked tile patches (dying+). Jagged polylines.
            if intensity >= 0.30 {
                let crackCount = Int(9.0 * intensity)
                for _ in 0..<crackCount {
                    guard let region = regions.randomElement(using: &rng) else { continue }
                    var x = CGFloat.random(in: region.minX..<region.maxX, using: &rng)
                    var y = CGFloat.random(in: region.minY..<region.maxY, using: &rng)
                    g.setStrokeColor(UIColor(white: 0.04,
                                              alpha: 0.55 * CGFloat(intensity)).cgColor)
                    g.setLineWidth(0.8)
                    g.move(to: CGPoint(x: x, y: y))
                    let segments = Int.random(in: 3..<6, using: &rng)
                    for _ in 0..<segments {
                        x += CGFloat.random(in: -12..<12, using: &rng)
                        y += CGFloat.random(in: -12..<12, using: &rng)
                        g.addLine(to: CGPoint(x: x, y: y))
                    }
                    g.strokePath()
                }
            }
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        cache[key] = texture
        return texture
    }
}
