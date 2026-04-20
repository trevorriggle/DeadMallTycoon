import Foundation

// v8: G.visitors entries
struct Visitor: Identifiable, Equatable {
    let id: UUID
    let name: String
    let personality: String          // key into Personalities.all
    let type: VisitorType
    let color: String                // hex (e.g. "#c4919a")
    let headColor: String            // hex
    let age: Int

    // presentation state — updated by SpriteKit frame loop, not by TickEngine
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var speed: Double

    var target: VisitorTarget?
    var state: VisitorState
    var dwellTimer: Int

    var memory: String               // last overheard thought
    var targetType: String           // "store" | "wander"
}
