import UIKit

// Color palette ported from v8's CSS. Values are literal hex strings so they can be
// compared against the HTML without translation.
enum Palette {

    // base
    static let backgroundNight    = UIColor(hex: "#0a0908")
    static let panelDark          = UIColor(hex: "#1a1917")
    static let panelMid           = UIColor(hex: "#1a1410")
    static let panelText          = UIColor(hex: "#e8dcc8")
    static let muted              = UIColor(hex: "#888780")
    static let border             = UIColor(hex: "#3a3935")
    static let borderMid          = UIColor(hex: "#5a4a3a")

    // corridor
    static let floor              = UIColor(hex: "#c8bca0")
    static let floorDot1          = UIColor(hex: "#a8818a")
    static let floorDot2          = UIColor(hex: "#5a9490")
    static let floorDot3          = UIColor(hex: "#7a6a5a")
    static let ceilingBg          = UIColor(hex: "#2a2520")
    static let wall               = UIColor(hex: "#4a7a75")
    static let wallBorder         = UIColor(hex: "#2a4a45")

    // wing sealed overlay (diagonal stripe)
    static let wingSealedA        = UIColor(hex: "#1a1410", alpha: 0.75)
    static let wingSealedB        = UIColor(hex: "#3a2a20", alpha: 0.75)
    static let wingSealedBorder   = UIColor(hex: "#5a4a3a")
    static let wingSealedLabel    = UIColor(hex: "#c4919a")

    // storefronts (tier fills)
    static let storeAnchor        = UIColor(hex: "#e8b888")
    static let storeAnchorBorder  = UIColor(hex: "#8a5a3a")
    static let storeStandard      = UIColor(hex: "#c4919a")
    static let storeStandardBorder = UIColor(hex: "#8a4a5a")
    static let storeKiosk         = UIColor(hex: "#a8c8d4")
    static let storeKioskBorder   = UIColor(hex: "#4a7a8a")
    static let storeSketchy       = UIColor(hex: "#9a8a7a")
    static let storeSketchyBorder = UIColor(hex: "#5a4a3a")
    static let storeVacant        = UIColor(hex: "#1a1814")
    static let storeVacantBorder  = UIColor(hex: "#0a0908")
    static let storeBoarded       = UIColor(hex: "#2a1a10")
    static let storeBoardedBorder = UIColor(hex: "#1a0a05")
    static let storeAbandoned     = UIColor(hex: "#0a0605")

    // store sign + window
    static let signLight          = UIColor(hex: "#e8dcc8")
    static let signDark           = UIColor(hex: "#2a2520")
    static let signVacantBg       = UIColor(hex: "#2a2520")
    static let signVacantFg       = UIColor(hex: "#4a4540")
    static let windowLit          = UIColor(hex: "#f4e4b0")
    static let windowDark         = UIColor(hex: "#0a0908")
    static let gateDark           = UIColor(hex: "#2a2520")
    static let gateLight          = UIColor(hex: "#4a4540")

    // decorations
    static let kugelHi            = UIColor(hex: "#a8a8a0")
    static let kugelLo            = UIColor(hex: "#3a3a32")
    static let kugelBorder        = UIColor(hex: "#1a1914")
    static let fountainHi         = UIColor(hex: "#4a7a8a")
    static let fountainLo         = UIColor(hex: "#1a3a45")
    static let fountainBrokenHi   = UIColor(hex: "#4a3a2a")
    static let fountainBrokenLo  = UIColor(hex: "#1a1a12")
    static let fountainBorder     = UIColor(hex: "#7a6a5a")
    static let benchFill          = UIColor(hex: "#4a3a2a")
    static let benchBorder        = UIColor(hex: "#2a1a0a")
    static let plantHi            = UIColor(hex: "#3a6a3a")
    static let plantLo            = UIColor(hex: "#1a3a1a")
    static let plantDeadHi        = UIColor(hex: "#6a5a3a")
    static let plantDeadLo        = UIColor(hex: "#3a2a1a")
    static let plantBorder        = UIColor(hex: "#2a1a0a")
    static let neonFill           = UIColor(hex: "#c4919a")
    static let neonBorder         = UIColor(hex: "#5a2a35")
    static let neonDark           = UIColor(hex: "#2a1a20")
    static let directoryFill      = UIColor(hex: "#5a4a3a")
    static let directoryBorder    = UIColor(hex: "#7a6a5a")
    static let directoryGlow      = UIColor(hex: "#fac775")

    // thought bubble
    static let bubbleBg           = UIColor(white: 1.0, alpha: 1.0)
    static let bubbleBorder       = UIColor(hex: "#2a2520")
    static let bubbleText         = UIColor(hex: "#2a2520")

    // abandonment dimming — brightness/saturation per level (v8 mall-dim-1..4)
    static let dimLevels: [(brightness: Double, saturation: Double)] = [
        (1.00, 1.00),   // 0 thriving
        (0.92, 1.00),   // 1 fading
        (0.82, 0.90),   // 2 struggling
        (0.70, 0.75),   // 3 dying
        (0.55, 0.50),   // 4 dead
    ]

    // threat colors
    static let threatGood         = UIColor(hex: "#5DCAA5")
    static let threatWarn         = UIColor(hex: "#EF9F27")
    static let threatDanger       = UIColor(hex: "#e24b4a")
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
