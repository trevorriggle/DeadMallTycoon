import Foundation

// v9 Prompt 10 Phase B — anchor-departure modal card flavor authoring.
//
// Lookup: `AnchorDepartureFlavor.line(for: tenantName)` returns the 2-3
// sentence longer-form body text displayed under the headline on the
// AnchorDepartureCardView. This is the weighty narrative moment that
// separates an anchor's closing from a run-of-the-mill tenant closure —
// the mall has just lost a pillar, and the prose should carry that.
//
// Claude Code does NOT write these. The placeholders below stay visible
// in the UI ("[flavor pending: …]") so authoring gaps are legible, not
// silent. Mirrors the Data/ClosureFlavor.swift convention.
//
// -----------------------------------------------------------------------------
// AUTHORING TODO — replace the "[flavor pending: …]" placeholders below.
// Voice: weighty, memorial, specific to the anchor. 2-3 sentences. Past-
// tense acknowledgment of what the mall has just lost, in the cultural
// register of the 80s/90s anchor store the fictional name evokes.
//
//   [ ] "Halvorsen"   (west anchor; north wing)
//   [ ] "Pemberton"   (east anchor; south wing)
//
// Fallback entry (`genericFallback`) fires if an anchor-tier tenant
// closes that isn't in the per-anchor table — e.g. a hypothetical future
// approachable anchor from Tenants.targetsAll, or a synthetic test case.
// Write this as a generic anchor-loss beat that doesn't assume a name.
//
//   [ ] generic anchor fallback
// -----------------------------------------------------------------------------
enum AnchorDepartureFlavor {

    // AUTHORING TODO: Trevor to audit and refine.
    // v9 Prompt 20 — scaffolding. Both anchor cards treat the closure as
    // a death in the family: specific, final, no melodrama. Distinct
    // cultural registers — Halvorsen is the mid-century regional chain
    // (appliances, housewares, shoe department); Pemberton is the
    // aspirational anchor (fashion floor, mannequins, glass cases).
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

    // Resolve the flavor body. Exact match first, generic second. Never
    // returns an empty string — the placeholder itself is the legible
    // signal that authoring is still owed.
    static func line(for tenantName: String) -> String {
        perAnchor[tenantName] ?? genericFallback
    }
}
