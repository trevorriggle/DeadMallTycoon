import Foundation

// v9 Prompt 4 Phase 1 — age cohort.
// Widened-bucket scheme: <30 → explorers (incl. kids — small people
// discovering an unfamiliar space), 30-55 → nostalgics, 56+ → originals.
// Matches the three-cohort spirit of the spec while covering every age the
// existing personality set produces (5-82).
enum AgeCohort: String, Codable, CaseIterable {
    case explorers   // 15-29 (and <15 kids fold in)
    case nostalgics  // 30-55
    case originals   // 56+

    var displayName: String {
        switch self {
        case .explorers:  return "The Explorers"
        case .nostalgics: return "The Nostalgics"
        case .originals:  return "The Originals"
        }
    }

    static func from(age: Int) -> AgeCohort {
        if age >= 56 { return .originals }
        if age >= 30 { return .nostalgics }
        return .explorers
    }

    // v9 Prompt 4 Phase 3 — memory weight multiplier per thought fire.
    // Originals ×2.5, Nostalgics ×1.5, Explorers ×1.0 per spec.
    var memoryWeightMultiplier: Double {
        switch self {
        case .originals:  return 2.5
        case .nostalgics: return 1.5
        case .explorers:  return 1.0
        }
    }
}

// v9 Prompt 4 Phase 1 — visitor mood enum.
// Narrative state. Populates plausibly at spawn; not tied to behavior.
enum VisitorMood: String, Codable, CaseIterable {
    case nostalgic, bored, curious, melancholy, amused
    case tired, annoyed, contemplative, hopeful, disappointed

    var displayName: String { rawValue.capitalized }
}

// v9 Prompt 4 Phase 1 — visitor activity enum.
// Narrative state. Surface for the profile panel; existing pathfinding
// continues to drive actual movement.
enum VisitorActivity: String, Codable, CaseIterable {
    case wandering, windowShopping, sitting
    case lookingForSomething, reminiscing, leaving

    var displayName: String {
        switch self {
        case .wandering:           return "Wandering"
        case .windowShopping:      return "Window shopping"
        case .sitting:             return "Sitting"
        case .lookingForSomething: return "Looking for something"
        case .reminiscing:         return "Reminiscing"
        case .leaving:             return "Leaving"
        }
    }
}

// v9 Prompt 4 Phase 1 — where the visitor says they're headed.
// Narrative. The storeSlotId case carries a concrete slot id so the panel
// can render "Heading to Brinkerhoff Books" by looking up the store name.
enum DestinationIntent: Equatable, Codable {
    case fountain
    case foodCourt
    case directory
    case store(slotId: Int)
    case nearestExit
    case noDestination

    var displayLabel: String {
        switch self {
        case .fountain:       return "The fountain"
        case .foodCourt:      return "The food court"
        case .directory:      return "The directory"
        case .store:          return "A store"
        case .nearestExit:    return "The nearest exit"
        case .noDestination:  return "Nowhere in particular"
        }
    }
}

// v8: G.visitors entries
// v9 Prompt 4 Phase 1 — expanded with identity + narrative state. Existing
// x/y/vx/vy/speed/target/state/dwellTimer continue to drive rendering and
// pathfinding; the new fields (firstName, lastName, cohort, mood, activity,
// destinationIntent) are presentation-state for the profile panel.
// tenantIdAffinity is reserved for the future returning-visitor system
// (Prompt 6+) — left nil in Prompt 4.
struct Visitor: Identifiable, Equatable {
    let id: UUID

    // v9 Prompt 4 Phase 1 — identity fields.
    let firstName: String
    let lastName: String
    let ageCohort: AgeCohort

    // Narrative state — set at spawn, can shift on thought events.
    var mood: VisitorMood
    var activity: VisitorActivity
    var destinationIntent: DestinationIntent

    // v8: personality / type / colors / age (unchanged).
    let personality: String          // key into Personalities.all
    let type: VisitorType
    let color: String                // hex (e.g. "#c4919a")
    let headColor: String            // hex
    let age: Int

    // v9 Prompt 4 Phase 1 — reserved for future returning-visitor identity
    // (a visitor who previously shopped at a specific tenant maintains an
    // affinity). Schema-reserved now so the later prompt doesn't need a
    // migration. Stays nil for the duration of Prompt 4.
    var tenantIdAffinity: Int? = nil

    // presentation state — updated by SpriteKit frame loop, not by TickEngine.
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var speed: Double

    var target: VisitorTarget?
    var state: VisitorState
    var dwellTimer: Int

    var memory: String               // last overheard thought (text only)
    var targetType: String           // "store" | "wander"

    // v9 Prompt 4 Phase 1 — convenience for UI that still expects a single
    // `name` string. Preserves existing call-site ergonomics after the
    // firstName/lastName split.
    var name: String { "\(firstName) \(lastName)" }
}

// v9 Prompt 4 Phase 6 — frozen identity snapshot for the profile panel.
// Visitor positions change every frame; storing the full Visitor in
// GameState would churn the Observation loop. The panel only needs the
// narrative fields plus the last-overheard thought text. This snapshot is
// set when vm.selectVisitor fires and cleared on vm.clearSelection.
struct VisitorIdentity: Equatable, Codable {
    let firstName: String
    let lastName: String
    let age: Int
    let ageCohort: AgeCohort
    let mood: VisitorMood
    let activity: VisitorActivity
    let destinationIntent: DestinationIntent
    let lastMemory: String

    var name: String { "\(firstName) \(lastName)" }

    init(from v: Visitor, memory: String) {
        self.firstName = v.firstName
        self.lastName = v.lastName
        self.age = v.age
        self.ageCohort = v.ageCohort
        self.mood = v.mood
        self.activity = v.activity
        self.destinationIntent = v.destinationIntent
        self.lastMemory = memory
    }
}
