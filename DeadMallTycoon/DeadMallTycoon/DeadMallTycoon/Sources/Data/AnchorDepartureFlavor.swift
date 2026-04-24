import Foundation

// v9 Prompt 10 Phase B — anchor-departure modal card flavor.
//
// Lookup: `AnchorDepartureFlavor.line(for: tenantName)` returns the 2-3
// sentence longer-form body text displayed under the headline on the
// AnchorDepartureCardView. This is the weighty narrative moment that
// separates an anchor's closing from a run-of-the-mill tenant closure —
// the mall has just lost a pillar, and the prose should carry that.
//
// Fallback fires for anchor-tier tenants not in the perAnchor table —
// e.g. a future approachable anchor from Tenants.targetsAll.
enum AnchorDepartureFlavor {

    // v9 Prompt 20 — both anchor cards treat the closure as a death in the
    // family: specific, final, no melodrama. Distinct cultural registers —
    // Halvorsen is the mid-century regional chain (appliances, housewares,
    // shoe department); Pemberton is the aspirational anchor (fashion
    // floor, mannequins, glass cases).
    //
    // Per-anchor authored lines. Keyed by the Store.name as it appears in
    // StartingMall.storeSeeds (the two seed-set anchors in the fictional
    // brand rename).
    private static let perAnchor: [String: String] = [
        "Halvorsen":
            "Halvorsen opened with the mall. Four decades, three generations, a whole floor of appliances "
            + "upstairs and a shoe department that remembered your kid's size. The terminal corridor goes "
            + "dark tonight. The letters come down in the morning.",
        "Pemberton":
            "Pemberton is closing. The glass cases, the perfume counter, the marble pillars by the "
            + "east escalator, the fashion floor with its own dedicated announcer. The mall that had a "
            + "Pemberton is a different mall than the one that doesn't. That mall is gone.",
    ]

    // Last-resort generic. Reached for anchor-tier tenants not in the
    // perAnchor table. Should read as a universal anchor-loss beat.
    private static let genericFallback: String =
        "The anchor is closing. A corridor the mall was built around will go dark. "
        + "The wing it headlined will never recover the traffic. Nothing replaces an anchor."

    // Resolve the flavor body. Exact match first, generic second.
    static func line(for tenantName: String) -> String {
        perAnchor[tenantName] ?? genericFallback
    }
}
