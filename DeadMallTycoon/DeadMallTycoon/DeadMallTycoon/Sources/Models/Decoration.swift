import Foundation
import CoreGraphics

// v8: DECORATION_TYPES entry
struct DecorationType: Equatable {
    let kind: DecorationKind
    let name: String
    let baseMult: Double
    let ruinMult: Double
    let size: CGSize
    let cost: Int
    let repair: Int
    let description: String
}

// v8: G.decorations entries (STARTING_DECORATIONS shape + runtime fields)
struct Decoration: Identifiable, Equatable, Codable {
    let id: Int
    var kind: DecorationKind
    var x: Double
    var y: Double
    var condition: Int               // 0..4, index into Condition
    var working: Bool
    var hazard: Bool
    var monthsAtCondition: Int
}

// v8: CONDITIONS array
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
