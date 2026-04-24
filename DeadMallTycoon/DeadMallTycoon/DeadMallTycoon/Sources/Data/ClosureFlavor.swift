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

    // AUTHORING TODO: Trevor to audit and refine.
    // v9 Prompt 20 — scaffolding lines. Memorial voice, emotionally specific
    // to each tenant archetype. Final copy pending Trevor's audit.
    //
    // Per-tenant authored lines. Keyed by the exact Store.name as it appears
    // in the catalog — StartingMall.storeSeeds and Catalog.Tenants.*.
    private static let perTenant: [String: String] = [
        // Anchors.
        "Halvorsen":            "Halvorsen. Forty years in the west wing. The letters came down on a Tuesday morning. Nobody said anything as it happened.",
        "Pemberton":            "Pemberton is gone. The mannequins in the front windows are still there, facing the corridor, waiting.",
        // Standards (starting).
        "Ricky's Records":      "Ricky's Records. The listening booth in the back where you discovered half of high school. Closed over the weekend. No sign, no note.",
        "Brinkerhoff Books":    "Brinkerhoff Books. The magazine rack where you spent entire afternoons. Gone this morning, sign already down.",
        "Sole Center":          "Sole Center. The bench by the register where kids got their first pair of real sneakers. Dark windows now.",
        "Razor & Rose":         "Razor & Rose. The cassette wall. The band shirts. The smell of incense. All of it boxed up in a weekend.",
        "Lulu & Lace":          "Lulu & Lace. The sale rack that everybody's mother pawed through. Shuttered between payrolls.",
        "Signal Shack":         "Signal Shack. The CB radios in the front window that nobody under forty understood. Packed up and moved on.",
        "Bell & Thornton":      "Bell & Thornton. Where the suburban dads bought their ties. The lease ran out and they didn't renew.",
        "Switchblade Novelty":  "Switchblade Novelty. The gag gifts, the joke books, the rubber vomit. A whole aesthetic, gone.",
        "Beckett Books":        "Beckett Books. The reading chair nobody policed. Staff who remembered your kids. Closed quiet.",
        // Kiosks (starting).
        "Cinna-Swirl":          "Cinna-Swirl. You could smell it from the parking lot. Now you can't.",
        "Julius & Co":          "Julius & Co. The orange cups. The line every Saturday at noon. Kiosk wheeled out in the dark.",
        "Shadecraft":           "Shadecraft. Sunglasses on a spinning rack. A whole teenage summer's worth of impulse buys. Folded up and gone.",
        "Auntie Rae's":         "Auntie Rae's. Fourteen years she stood behind that counter. She knew your pretzel order. She's retired now.",
        // Sketchy (starting + offer pool).
        "Vape Shop":            "The vape shop closed. No ceremony. The landlord changed the locks overnight.",
        // Offer pool — only close after being signed.
        "The Edition":          "The Edition. The big national window displays that pulled the teenagers in. They pulled out of the region.",
        "Basin & Bloom":        "Basin & Bloom. The candle wall everyone's aunt bought from. Shelves bare by Monday.",
        "GameVault":            "GameVault. The demo station nobody's kid would leave. Gone over spring break.",
        "BellWave":             "BellWave. The mall's cell phone store. Closed the month after the carrier opened a kiosk at the supercenter.",
        "Via Roma":             "Via Roma. The food court slice that fed three generations of teenagers. Oven's off.",
        "Phantasm Seasonal":    "Phantasm Seasonal. Four months a year of fog machines and rubber masks. Didn't come back this fall.",
        "Escape Room":          "The escape room outfit. Took over a dead storefront for two years. Now it's a dead storefront again.",
        "Pawn Outlet":          "The pawn outlet. Barred windows, case lights still on some nights. Closed without a sign.",
    ]

    // Tier-level fallbacks. Fire when a tenant name has no authored entry —
    // e.g. a new tenant added to the catalog without ClosureFlavor coverage,
    // or a scripted event closure whose tenant isn't in the per-tenant table.
    private static let perTier: [StoreTier: String] = [
        .anchor:   "An anchor has gone dark. The wing will never feel the same.",
        .standard: "A storefront closed over the weekend. The signs came down before anyone noticed.",
        .kiosk:    "The kiosk is gone. A blank square of unworn tile where it stood.",
        .sketchy:  "They closed without warning. The security gate stayed locked after Friday.",
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
