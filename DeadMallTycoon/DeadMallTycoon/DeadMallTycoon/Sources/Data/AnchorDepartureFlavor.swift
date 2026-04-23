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

    // Per-anchor authored lines. Keyed by the Store.name as it appears in
    // StartingMall.storeSeeds (the two seed-set anchors in the fictional
    // brand rename).
    private static let perAnchor: [String: String] = [
        "Halvorsen":  "[flavor pending: Halvorsen — 2-3 sentences]",
        "Pemberton":  "[flavor pending: Pemberton — 2-3 sentences]",
    ]

    // Last-resort generic. Reached for anchor-tier tenants not in the
    // perAnchor table. Should read as a universal anchor-loss beat.
    private static let genericFallback: String =
        "[flavor pending: generic anchor fallback]"

    // Resolve the flavor body. Exact match first, generic second. Never
    // returns an empty string — the placeholder itself is the legible
    // signal that authoring is still owed.
    static func line(for tenantName: String) -> String {
        perAnchor[tenantName] ?? genericFallback
    }
}
