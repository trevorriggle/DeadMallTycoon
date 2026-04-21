import UIKit

// Color palette — reskinned from the original v8 warm-autumnal (tan/coral/brown/
// orange) mall aesthetic to a cool "dead-mall cyberpunk" tone: concrete greys,
// neon pink storefronts, icy blue kiosks + daylight, near-black voids. Property
// names are preserved so TextureFactory / StoreNode / SceneLoad all keep working
// — only the color values shift.
enum Palette {

    // base
    static let backgroundNight    = UIColor(hex: "#0a0a0e")
    static let panelDark          = UIColor(hex: "#14141a")
    static let panelMid           = UIColor(hex: "#1a1a22")
    static let panelText          = UIColor(hex: "#d8d8e0")
    static let muted              = UIColor(hex: "#6a6a78")
    static let border             = UIColor(hex: "#2a2a34")
    static let borderMid          = UIColor(hex: "#3a3a48")

    // corridor
    static let floor              = UIColor(hex: "#b8b8c0")   // light concrete grey
    static let floorDot1          = UIColor(hex: "#ff4dbd")   // neon pink accent
    static let floorDot2          = UIColor(hex: "#7fd3f0")   // ice blue accent
    static let floorDot3          = UIColor(hex: "#5a5a68")   // darker grey accent
    static let ceilingBg          = UIColor(hex: "#1a1a22")
    static let wall               = UIColor(hex: "#4a4a5a")
    static let wallBorder         = UIColor(hex: "#2a2a34")

    // wing sealed overlay (diagonal stripe)
    static let wingSealedA        = UIColor(hex: "#14141a", alpha: 0.78)
    static let wingSealedB        = UIColor(hex: "#2a2a34", alpha: 0.78)
    static let wingSealedBorder   = UIColor(hex: "#3a3a48")
    static let wingSealedLabel    = UIColor(hex: "#ff4dbd")

    // storefronts (tier fills)
    static let storeAnchor        = UIColor(hex: "#a8b8c8")   // pale cool blue-grey
    static let storeAnchorBorder  = UIColor(hex: "#4a5a6a")
    static let storeStandard      = UIColor(hex: "#ff4dbd")   // neon pink retail
    static let storeStandardBorder = UIColor(hex: "#8a2a6a")
    static let storeKiosk         = UIColor(hex: "#7fd3f0")   // ice blue kiosk
    static let storeKioskBorder   = UIColor(hex: "#2a5a7a")
    static let storeSketchy       = UIColor(hex: "#4a4a54")
    static let storeSketchyBorder = UIColor(hex: "#1a1a22")
    static let storeVacant        = UIColor(hex: "#14141a")
    static let storeVacantBorder  = UIColor(hex: "#0a0a0e")
    static let storeBoarded       = UIColor(hex: "#1a1a22")
    static let storeBoardedBorder = UIColor(hex: "#0a0a0e")
    static let storeAbandoned     = UIColor(hex: "#050508")

    // store sign + window
    static let signLight          = UIColor(hex: "#e8e8f0")
    static let signDark           = UIColor(hex: "#14141a")
    static let signVacantBg       = UIColor(hex: "#14141a")
    static let signVacantFg       = UIColor(hex: "#3a3a48")
    static let windowLit          = UIColor(hex: "#b8e8f8")   // ice-blue daylight
    static let windowDark         = UIColor(hex: "#0a0a0e")
    static let gateDark           = UIColor(hex: "#14141a")
    static let gateLight          = UIColor(hex: "#2a2a34")

    // decorations
    static let kugelHi            = UIColor(hex: "#c8c8d4")   // chrome ball
    static let kugelLo            = UIColor(hex: "#3a3a48")
    static let kugelBorder        = UIColor(hex: "#1a1a22")
    static let fountainHi         = UIColor(hex: "#7fd3f0")   // cyan water
    static let fountainLo         = UIColor(hex: "#1a4a68")
    static let fountainBrokenHi   = UIColor(hex: "#4a4a54")
    static let fountainBrokenLo   = UIColor(hex: "#1a1a22")
    static let fountainBorder     = UIColor(hex: "#6a6a78")
    static let benchFill          = UIColor(hex: "#3a3a48")
    static let benchBorder        = UIColor(hex: "#1a1a22")
    static let plantHi            = UIColor(hex: "#4aa8a0")   // teal-green
    static let plantLo            = UIColor(hex: "#1a4a48")
    static let plantDeadHi        = UIColor(hex: "#6a6a68")
    static let plantDeadLo        = UIColor(hex: "#3a3a48")
    static let plantBorder        = UIColor(hex: "#1a1a22")
    static let neonFill           = UIColor(hex: "#ff4dbd")
    static let neonBorder         = UIColor(hex: "#8a2a6a")
    static let neonDark           = UIColor(hex: "#1a0a18")
    static let directoryFill      = UIColor(hex: "#3a3a48")
    static let directoryBorder    = UIColor(hex: "#6a6a78")
    static let directoryGlow      = UIColor(hex: "#7fd3f0")   // icy cyan

    // thought bubble
    static let bubbleBg           = UIColor(white: 1.0, alpha: 1.0)
    static let bubbleBorder       = UIColor(hex: "#14141a")
    static let bubbleText         = UIColor(hex: "#14141a")

    // abandonment dimming — brightness/saturation per level (v8 mall-dim-1..4)
    static let dimLevels: [(brightness: Double, saturation: Double)] = [
        (1.00, 1.00),   // 0 thriving
        (0.92, 1.00),   // 1 fading
        (0.82, 0.90),   // 2 struggling
        (0.70, 0.75),   // 3 dying
        (0.55, 0.50),   // 4 dead
    ]

    // threat colors — keep semantic meaning (good/warn/danger) but reskinned
    // cool: mint for safe, neon pink for heads-up, hot red for true danger.
    static let threatGood         = UIColor(hex: "#5fe0b8")
    static let threatWarn         = UIColor(hex: "#ff4dbd")
    static let threatDanger       = UIColor(hex: "#ff2f4a")
}

extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var cleaned = hex.uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let v = UInt32(cleaned, radix: 16) else {
            self.init(white: 0.5, alpha: alpha)
            return
        }
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >>  8) & 0xFF) / 255.0
        let b = CGFloat( v        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
