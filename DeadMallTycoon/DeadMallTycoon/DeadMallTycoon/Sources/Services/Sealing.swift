import Foundation

// v9 Prompt 19 — eligibility queries for the sealing sheet.
//
// Three surfaces, one namespace. Each helper returns the candidates that
// SHOULD be listed in the corresponding section of SealingSheet. Sealing
// is always allowed for eligible candidates — the wing eligibility rule
// is deliberately permissive (all un-sealed wings listed; the sheet
// renders an advisory for partially-occupied wings via
// wingOccupancyAdvisory, it does NOT gate). Per designer decision during
// Prompt 19 scoping: "list all un-sealed wings, show advisory text for
// partially-occupied wings, no gating."
enum Sealing {

    // All wings not currently closed. Sealing a wing is always permitted;
    // an advisory string (see wingOccupancyAdvisory) reads the occupancy
    // and surfaces a soft warning when a wing still has active tenants.
    static func eligibleWings(in state: GameState) -> [Wing] {
        Wing.allCases.filter { !Mall.isWingClosed($0, in: state) }
    }

    // Entrances that are currently OPEN — i.e., both not individually
    // sealed AND their wing is not closed. Mall.openEntrances encodes the
    // same rule; reused here so a wing-closed corner doesn't show up as a
    // sealable entrance.
    static func eligibleEntrances(in state: GameState) -> [EntranceCorner] {
        Array(Mall.openEntrances(in: state))
            .sorted { $0.rawValue < $1.rawValue }
    }

    // Boarded storefronts (and displaySpaces, matching ArtifactActions.sealStorefront's
    // gate) available to convert into sealedStorefront memorials.
    // DisplaySpaces are included because sealing them IS a valid terminal
    // curation move — but the sheet renders them distinctly so the player
    // understands they're giving up the display.
    static func eligibleStorefronts(in state: GameState) -> [Artifact] {
        state.artifacts
            .filter { $0.type == .boardedStorefront || $0.type == .displaySpace }
            .sorted { $0.id < $1.id }
    }

    // v9 Prompt 19 — per-wing occupancy advisory, computed for the sheet
    // row. Returns a short string when the wing still has active tenants
    // (sealing would close them out); nil when the wing is already mostly
    // empty and sealing is the obvious move.
    //
    // Threshold matches the tutorial-beat trigger (< 50% non-vacant):
    // below that, no advisory; at/above, surface the count of tenants
    // that would be lost so the confirmation preview isn't the first
    // place the player sees the cost.
    static func wingOccupancyAdvisory(for wing: Wing, in state: GameState) -> String? {
        let stores = state.stores.filter { $0.wing == wing }
        guard !stores.isEmpty else { return nil }
        let active = stores.filter { $0.tier != .vacant }.count
        let ratio = Double(active) / Double(stores.count)
        if ratio < 0.5 { return nil }
        if active == 1 { return "1 active tenant would close" }
        return "\(active) active tenants would close"
    }

    // v9 Prompt 19 — count of active (non-vacant) tenants in a wing.
    // Used by the confirmation preview for the consequences line ("this
    // will close N storefronts permanently").
    static func activeTenantCount(in wing: Wing, _ state: GameState) -> Int {
        state.stores
            .filter { $0.wing == wing && $0.tier != .vacant }
            .count
    }
}
