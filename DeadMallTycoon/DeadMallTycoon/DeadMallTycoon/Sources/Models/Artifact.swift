import Foundation

// v9: Artifacts are the primary memorial entity. Prompt 3 expands Artifact into
// the unified type for every placed physical feature in the mall — subsuming
// what was previously the separate Decoration model. The Decoration struct,
// DecorationType, and DecorationKind enum have all been deleted; their fields
// and responsibilities live here now.
//
// Future prompt: memory weight accumulation (Prompt 5), thought-bubble salience
// consumes thoughtTriggers (Prompt 5+), tenant-identity system may populate
// tenantId (later). If you are opening this file and wondering why some fields
// seem speculative, the rollout is staged: model first, consumers later.

// v8: CONDITIONS array.
// v9 Prompt 3 — migrated from the deleted Decoration.swift. Same ladder,
// same display names. Read by ArtifactInfoCard + ArtifactDebugPanel.
enum Condition: Int, CaseIterable {
    case pristine = 0, worn, damaged, deteriorating, ruin

    var name: String {
        switch self {
        case .pristine: return "Pristine"
        case .worn: return "Worn"
        case .damaged: return "Damaged"
        case .deteriorating: return "Deteriorating"
        case .ruin: return "Ruin"
        }
    }
}

// v8: DECORATION_TYPES keys (kugel, fountain, plant, neon, bench, directory)
//     merged with Prompt 1's speculative ambient-artifact taxonomy.
// v9 Prompt 3 — unified taxonomy. The Prompt 1 speculative state-variant cases
// (stoppedFountain, flickeringNeon, ruinedKugelBall, outdatedDirectory) were
// deleted; ruin is now expressed via the condition/working fields on the
// unified object type (e.g. fountain + condition 4 = a stopped fountain).
enum ArtifactType: String, Codable, CaseIterable, Equatable {
    // Placeable — formerly DecorationKind cases (same stats, new home).
    case kugelBall           // v8: DECORATION_TYPES.kugel
    case fountain            // v8: DECORATION_TYPES.fountain
    case planter             // v8: DECORATION_TYPES.plant
    case neonSign            // v8: DECORATION_TYPES.neon
    case bench               // v8: DECORATION_TYPES.bench
    case directoryBoard      // v8: DECORATION_TYPES.directory

    // Placeable — period-appropriate seed set (Prompt 3, also pre-placed in StartingMall).
    case skylight            // v9 Prompt 3 — new
    case terrazzoFlooring    // v9 Prompt 3 — new

    // Placeable — Prompt 3 roster expansion.
    case payPhoneBank                 // v9 Prompt 3 — new
    case cigaretteVendingMachine      // v9 Prompt 3 — new
    case coinOperatedHorseRide        // v9 Prompt 3 — new
    case photoBooth                   // v9 Prompt 3 — new
    case massageChair                 // v9 Prompt 3 — new
    case brassRailing                 // v9 Prompt 3 — new
    case terrazzoInlay                // v9 Prompt 3 — new
    case sunkenSeatingPit             // v9 Prompt 3 — new
    case deadFicus                    // v9 Prompt 3 — new (planter with dead ficus; distinct type for flavor)
    case waterStainedCeiling          // v9 Prompt 3 — new (ceiling tile)
    case flickeringFluorescent        // v9 Prompt 3 — new
    case emergencyExitSign            // v9 Prompt 3 — new
    case arcadeCabinet                // v9 Prompt 3 — new (decommissioned pay-to-play)
    case christmasLeftUp              // v9 Prompt 3 — new (decorations left up past February)
    case lostAndFoundCabinet          // v9 Prompt 3 — new
    case pretzelRemnant               // v9 Prompt 3 — new (pretzel kiosk remnant)
    case crackedTile                  // v9 Prompt 3 — new
    case memorialBench                // v9 Prompt 3 — new (bench with a plaque to someone nobody remembers)

    // Ambient / event-spawned (not player-placeable; cost == 0 in catalog).
    case boardedStorefront   // v9 Prompt 2 — tenant closure memorial
    case sealedEntrance      // v9 Prompt 1 — reserved; not spawned in mechanics yet
    case emptyFoodCourt      // v9 Prompt 1 — reserved
    case custom              // escape hatch for scripted / event content
}

// v9: Origin tracks what caused an artifact to exist. Kept as a three-case
// enum so downstream prompts can pattern-match on .tenant(name:) vs
// .event(name:) vs .playerAction(…) without re-parsing strings.
enum ArtifactOrigin: Equatable, Codable {
    case tenant(name: String)
    case event(name: String)
    case playerAction(String)
}

// v8: G.decorations entries + PROMPT-1 Artifact fields, merged.
// v9 Prompt 3 — unified struct. The x / y / working / hazard / monthsAtCondition
// fields migrated from the deleted Decoration struct. The storeSlotId +
// tenantId fields are Prompt 2 additions for slot-anchored memorial artifacts.
//
// Spatial fields (x, y) are optional: populated for corridor-placed artifacts,
// nil for slot-anchored (boardedStorefront uses storeSlotId) or ambient
// (emptyFoodCourt, sealedEntrance) artifacts.
struct Artifact: Identifiable, Equatable, Codable {
    let id: Int
    var name: String
    var type: ArtifactType
    var yearCreated: Int
    var condition: Int            // 0..4, parallel to Condition enum
    var memoryWeight: Double      // starts at 0, accumulates later (Prompt 5)
    var origin: ArtifactOrigin
    var thoughtTriggers: [String] // pool specific to this artifact instance

    // v9 Prompt 2 — slot-anchor reference.
    var storeSlotId: Int? = nil
    // v9 Prompt 2 — reserved for future tenant-identity system.
    var tenantId: Int? = nil

    // v8: G.decorations[i].x, .y — corridor position.
    // v9 Prompt 3 — migrated from deleted Decoration.
    var x: Double? = nil
    var y: Double? = nil

    // v8: G.decorations[i].working — kugel spins, fountain runs, neon lit.
    // v9 Prompt 3 — migrated from deleted Decoration.
    var working: Bool = true

    // v8: G.decorations[i].hazard — decayed to ruin + flagged, fines active.
    // v9 Prompt 3 — migrated from deleted Decoration.
    var hazard: Bool = false

    // v8: G.decorations[i].monthsAtCondition — dwell counter for pacing.
    // v9 Prompt 3 — migrated from deleted Decoration.
    var monthsAtCondition: Int = 0

    // v9 Prompt 5 — decay amplifier on memorial value. The thesis is "compose a
    // ruin": decayed artifacts carry more memorial weight than pristine ones.
    // Scoring consumes this as memoryWeight × decayMultiplier.
    //   pristine (0)      → 1.00×
    //   worn (1)          → 1.25×
    //   damaged (2)       → 1.50×
    //   deteriorating (3) → 1.75×
    //   ruin (4+)         → 2.00× (capped)
    // Curve: 1.0 + condition × 0.25, clamped to [1.0, 2.0].
    var decayMultiplier: Double {
        let c = max(0, min(4, condition))
        return 1.0 + Double(c) * 0.25
    }
}
