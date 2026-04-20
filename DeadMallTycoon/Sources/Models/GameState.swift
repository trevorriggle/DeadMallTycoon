import Foundation

// Root game state. Pure value type.
// Ported from the v8 `G` object. TickEngine.tick(state, rng) reads and returns a GameState.
struct GameState: Equatable {

    // clock — v8: G.m, G.y
    var month: Int = 0                    // 0..11
    var year: Int = GameConstants.startingYear

    // money — v8: G.cash, G.debt, G.score, G.lastMonthlyScore, G.hazardFines
    var cash: Int = GameConstants.startingCash
    var debt: Int = 0
    var score: Int = 0
    var lastMonthlyScore: Int = 0
    var hazardFines: Int = 0

    // world — v8: G.stores, G.decorations, G.visitors
    var stores: [Store] = []
    var decorations: [Decoration] = []
    var visitors: [Visitor] = []

    // operations — v8: G.spd, G.activePromos, G.activeAdDeals, G.activeStaff
    var speed: Speed = .x1
    var activePromos: [ActivePromotion] = []
    var activeAdDeals: [AdDeal] = []
    var activeStaff: StaffLoadout = StaffLoadout()
    var wingsClosed: [Wing: Bool] = [.north: false, .south: false]
    var wingsDowngraded: [Wing: Bool] = [.north: false, .south: false]

    // threat + traffic — v8: G.threatMeter, G.currentTraffic, G.consecutiveLowTrafficMonths, G.gangMonths
    var threatMeter: Double = 0
    var currentTraffic: Int = 0
    var consecutiveLowTrafficMonths: Int = 0
    var gangMonths: Int = 0

    // UI / flow — v8: G.currentTab, G.warnings, G.thoughtsLog, G.decision, G.paused, G.gameover, G.started, G.openingCrisis, G.pendingLawsuitMonth
    var currentTab: Tab = .mall
    var warnings: [Warning] = []
    var thoughtsLog: [ThoughtLogEntry] = []
    var decision: Decision? = nil
    var paused: Bool = false
    var gameover: Bool = false
    var started: Bool = false
    var openingCrisis: Bool = true
    var pendingLawsuitMonth: Int? = nil

    // selection — v8: G.selectedVisitor, G.selectedStore, G.selectedDec, G.selectedVisitorThought
    var selectedVisitorId: UUID? = nil
    var selectedStoreId: Int? = nil
    var selectedDecorationId: Int? = nil
    var selectedVisitorThought: String = ""

    // decoration placement mode — v8: G.placingDecoration
    var placingDecoration: DecorationKind? = nil

    // v9 addition — populated by TickEngine each month, rendered as sparkline in Phase 5
    var scoreHistory: RingBuffer<Int> = RingBuffer(capacity: 12)
}
