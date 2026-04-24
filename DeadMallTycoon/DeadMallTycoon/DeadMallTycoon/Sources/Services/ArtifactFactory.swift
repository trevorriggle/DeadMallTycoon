import Foundation

// v9: Construction helpers for Artifact. No mechanics — creation only.
// Prompt 3 — default thought triggers now come from ArtifactCatalog.info(type),
// not a per-prompt inline table. Single source of truth for catalog data.
enum ArtifactFactory {

    // v9: Build an artifact with the caller-supplied id. Mirrors how Decoration
    // ids used to be assigned by callers (see ArtifactActions.place).
    // Defaults: condition 0 (Pristine), memoryWeight 0, no slot/tenant ref,
    // no corridor position, working true, no hazard.
    // Prompt 2: storeSlotId and tenantId optional parameters for slot-anchored.
    // Prompt 3: x, y, working, hazard, monthsAtCondition surfaced via overloads
    // below for the placement path; keep the simple form for event spawns.
    static func make(id: Int,
                     type: ArtifactType,
                     name: String,
                     origin: ArtifactOrigin,
                     yearCreated: Int,
                     thoughtTriggers: [String]? = nil,
                     storeSlotId: Int? = nil,
                     tenantId: Int? = nil,
                     x: Double? = nil,
                     y: Double? = nil,
                     working: Bool = true,
                     hazard: Bool = false) -> Artifact {
        Artifact(
            id: id,
            name: name,
            type: type,
            yearCreated: yearCreated,
            condition: 0,
            memoryWeight: 0,
            origin: origin,
            thoughtTriggers: thoughtTriggers ?? defaultThoughtTriggers(for: type),
            storeSlotId: storeSlotId,
            tenantId: tenantId,
            x: x,
            y: y,
            working: working,
            hazard: hazard,
            monthsAtCondition: 0
        )
    }

    // v9 Prompt 3 — pulled from ArtifactCatalog so this function remains the
    // single place callers look for "default" triggers.
    static func defaultThoughtTriggers(for type: ArtifactType) -> [String] {
        ArtifactCatalog.info(type).defaultTriggers
    }
}
