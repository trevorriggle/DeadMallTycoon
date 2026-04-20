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

    // MARK: - Storefront background (by tier and state)

    static func storefrontTexture(tier: StoreTier, state: StorefrontVisualState,
                                  size: CGSize) -> SKTexture {
        let key = "store_\(tier.rawValue)_\(state.rawValue)_\(Int(size.width))x\(Int(size.height))"
        return cached(key) {
            SKTexture(image: renderImage(size: size) { ctx, size in
                let (fill, border): (UIColor, UIColor) = {
                    if tier == .vacant {
                        switch state {
                        case .boarded:       return (Palette.storeBoarded,   Palette.storeBoardedBorder)
                        case .longAbandoned: return (Palette.storeAbandoned, Palette.storeVacantBorder)
                        default:             return (Palette.storeVacant,    Palette.storeVacantBorder)
                        }
                    }
                    switch tier {
                    case .anchor:   return (Palette.storeAnchor,   Palette.storeAnchorBorder)
                    case .standard: return (Palette.storeStandard, Palette.storeStandardBorder)
                    case .kiosk:    return (Palette.storeKiosk,    Palette.storeKioskBorder)
                    case .sketchy:  return (Palette.storeSketchy,  Palette.storeSketchyBorder)
                    default:        return (Palette.storeStandard, Palette.storeStandardBorder)
                    }
                }()
                fill.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                border.setStroke()
                ctx.setLineWidth(2)
                ctx.stroke(CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2))
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
