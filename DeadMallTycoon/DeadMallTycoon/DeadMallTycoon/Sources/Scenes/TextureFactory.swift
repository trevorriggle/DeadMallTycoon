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

    // MARK: - Artifact overlays (v9, Prompt 2)

    // v9: Procedural pixel-art plywood panel for boardedStorefront artifacts.
    // Drawn as an overlay on top of the existing StoreNode sprite. Three to
    // four horizontal planks with nail dots + one prominent diagonal board —
    // the universal "boarded up" visual language.
    //
    // Size is caller-provided (matches the host storefront) so one slot's
    // overlay always fits its slot. Cached by dimension.
    static func boardedStorefrontOverlayTexture(size: CGSize) -> SKTexture {
        let key = "boardedOverlay_\(Int(size.width))x\(Int(size.height))"
        return cached(key) {
            SKTexture(image: renderImage(size: size) { ctx, size in
                let rect = CGRect(origin: .zero, size: size)

                // Dark weathered plywood fill.
                UIColor(red: 0.23, green: 0.17, blue: 0.11, alpha: 0.92).setFill()
                ctx.fill(rect)

                // Horizontal plank divisions — 3 planks on short nodes, 4 on tall.
                let plankCount: Int = size.height > 100 ? 4 : 3
                let plankHeight = size.height / CGFloat(plankCount)
                UIColor(red: 0.14, green: 0.10, blue: 0.06, alpha: 1.0).setStroke()
                ctx.setLineWidth(1.5)
                for i in 1..<plankCount {
                    let y = plankHeight * CGFloat(i)
                    ctx.move(to: CGPoint(x: 0, y: y))
                    ctx.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.strokePath()
                }

                // Woodgrain streaks — thin lighter horizontal lines scattered.
                UIColor(red: 0.32, green: 0.24, blue: 0.16, alpha: 0.45).setStroke()
                ctx.setLineWidth(0.5)
                let streakCount = max(3, Int(size.height / 18))
                for i in 0..<streakCount {
                    let y = CGFloat(i + 1) * (size.height / CGFloat(streakCount + 1)) + 2
                    ctx.move(to: CGPoint(x: 2, y: y))
                    ctx.addLine(to: CGPoint(x: size.width - 2, y: y))
                    ctx.strokePath()
                }

                // Nail dots at plank ends — two per plank, inset from edges.
                UIColor(red: 0.08, green: 0.06, blue: 0.04, alpha: 1.0).setFill()
                let nailRadius: CGFloat = 1.5
                for p in 0..<plankCount {
                    let cy = plankHeight * CGFloat(p) + plankHeight / 2
                    for x in [CGFloat(6), size.width - 6] {
                        ctx.fillEllipse(in: CGRect(x: x - nailRadius,
                                                    y: cy - nailRadius,
                                                    width: nailRadius * 2,
                                                    height: nailRadius * 2))
                    }
                }

                // Diagonal "X" board — corner-to-corner + opposite corner.
                UIColor(red: 0.18, green: 0.13, blue: 0.09, alpha: 0.9).setStroke()
                ctx.setLineWidth(3)
                ctx.move(to: CGPoint(x: 0, y: 0))
                ctx.addLine(to: CGPoint(x: size.width, y: size.height))
                ctx.move(to: CGPoint(x: size.width, y: 0))
                ctx.addLine(to: CGPoint(x: 0, y: size.height))
                ctx.strokePath()

                // Outer border — thin darker outline so the overlay reads as a
                // distinct panel applied on top of the storefront.
                UIColor.black.withAlphaComponent(0.6).setStroke()
                ctx.setLineWidth(1.5)
                ctx.stroke(rect.insetBy(dx: 0.75, dy: 0.75))
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
