import Foundation

// v9 Prompt 6 — authored closure flavor lines.
//
// Lookup order inside `line(for:)`:
//   1. Exact tenant-name match in `perTenant`.
//   2. Tier fallback in `perTier` (anchor / standard / kiosk / sketchy).
//   3. Neutral template: "<name> has closed after <N> years."
//
// All specific entries ship as "[flavor line pending]" and need authoring.
// Claude Code does NOT write these — they're the emotional beat that makes
// the closure card a memorial instead of a notification. See AUTHORING TODO
// below for the exact checklist.
//
// -----------------------------------------------------------------------------
// AUTHORING TODO — replace "[flavor line pending]" for each of these entries.
// Voice: memorial loss. One or two sentences for standards / kiosks / sketchy;
// two or three sentences for anchors.
//
// Starting-mall tenants (seeded in StartingMall.storeSeeds):
//   [ ] "Halvorsen"            (anchor)
//   [ ] "Pemberton"         (anchor)
//   [ ] "Ricky's Records"        (standard)
//   [ ] "Brinkerhoff Books"      (standard)
//   [ ] "Sole Center"      (standard)
//   [ ] "Razor & Rose"        (standard)
//   [ ] "Lulu & Lace"         (standard)
//   [ ] "Signal Shack"      (standard)
//   [ ] "Bell & Thornton"     (standard)
//   [ ] "Switchblade Novelty"        (standard)
//   [ ] "Beckett Books"        (standard)
//   [ ] "Cinna-Swirl"         (kiosk)
//   [ ] "Julius & Co"    (kiosk)
//   [ ] "Shadecraft"     (kiosk)
//   [ ] "Auntie Rae's"    (kiosk)
//   [ ] "Vape Shop"        (sketchy — also appears in offer pool)
//
// Offer-pool tenants (Catalog.Tenants.*; these can only close after being
// signed, so lines only fire if the player ever accepts them):
//   [ ] "The Edition"       (standard)
//   [ ] "Basin & Bloom" (standard)
//   [ ] "GameVault"          (standard)
//   [ ] "BellWave"          (standard)
//   [ ] "Via Roma"            (kiosk)
//   [ ] "Phantasm Seasonal"  (kiosk)
//   [ ] "Escape Room"       (sketchy)
//   [ ] "Pawn Outlet"       (sketchy)
//
// Tier fallbacks — fire when a retailer has no per-name entry (e.g. a future
// tenant added to the catalog without a flavor line, or a custom-event
// closure). Write these as a generic memorial for the retail class.
//   [ ] anchor   fallback
//   [ ] standard fallback
//   [ ] kiosk    fallback
//   [ ] sketchy  fallback
//
// The neutral "<name> has closed after <N> years." template in `neutralFallback`
// is a last-resort hedge; it should be unreachable once all entries above are
// authored (unless a new tier is added).
// -----------------------------------------------------------------------------
enum ClosureFlavor {

    // Per-tenant authored lines. Keyed by the exact Store.name as it appears
    // in the catalog — StartingMall.storeSeeds and Catalog.Tenants.*.
    private static let perTenant: [String: String] = [
        // Anchors.
        "Halvorsen":            "[flavor line pending]",
        "Pemberton":         "[flavor line pending]",
        // Standards (starting).
        "Ricky's Records":        "[flavor line pending]",
        "Brinkerhoff Books":      "[flavor line pending]",
        "Sole Center":      "[flavor line pending]",
        "Razor & Rose":        "[flavor line pending]",
        "Lulu & Lace":         "[flavor line pending]",
        "Signal Shack":      "[flavor line pending]",
        "Bell & Thornton":     "[flavor line pending]",
        "Switchblade Novelty":        "[flavor line pending]",
        "Beckett Books":        "[flavor line pending]",
        // Kiosks (starting).
        "Cinna-Swirl":         "[flavor line pending]",
        "Julius & Co":    "[flavor line pending]",
        "Shadecraft":     "[flavor line pending]",
        "Auntie Rae's":    "[flavor line pending]",
        // Sketchy (starting + offer pool).
        "Vape Shop":        "[flavor line pending]",
        // Offer pool — only close after being signed.
        "The Edition":       "[flavor line pending]",
        "Basin & Bloom": "[flavor line pending]",
        "GameVault":          "[flavor line pending]",
        "BellWave":          "[flavor line pending]",
        "Via Roma":            "[flavor line pending]",
        "Phantasm Seasonal":  "[flavor line pending]",
        "Escape Room":       "[flavor line pending]",
        "Pawn Outlet":       "[flavor line pending]",
    ]

    // Tier-level fallbacks. Fire when a tenant name has no authored entry —
    // e.g. a new tenant added to the catalog without ClosureFlavor coverage,
    // or a scripted event closure whose tenant isn't in the per-tenant table.
    private static let perTier: [StoreTier: String] = [
        .anchor:   "[flavor line pending]",
        .standard: "[flavor line pending]",
        .kiosk:    "[flavor line pending]",
        .sketchy:  "[flavor line pending]",
    ]

    // Last-resort neutral template. Computed, not looked up, because it
    // interpolates the tenant name and years-open. Reached only if a new
    // StoreTier is added without a perTier entry — currently unreachable.
    private static func neutralFallback(name: String, yearsOpen: Int) -> String {
        let yearPhrase = yearsOpen == 1 ? "1 year" : "\(yearsOpen) years"
        return "\(name) has closed after \(yearPhrase)."
    }

    // Resolve the flavor line for a ClosureEvent. Exact match → tier
    // fallback → neutral template. Returns an authored line when present;
    // otherwise the placeholder string is returned verbatim so the UI shows
    // "[flavor line pending]" — a legible signal that the entry still needs
    // writing, not a silent miss.
    static func line(for event: ClosureEvent) -> String {
        if let specific = perTenant[event.tenantName] { return specific }
        if let tierLine = perTier[event.tenantTier] { return tierLine }
        return neutralFallback(name: event.tenantName, yearsOpen: event.yearsOpen)
    }
}
