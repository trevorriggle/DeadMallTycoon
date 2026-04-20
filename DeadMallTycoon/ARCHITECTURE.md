# Dead Mall Tycoon — Architecture

*Phase 1 scaffold. This document is the contract between the v8 HTML prototype and the native iPad port. Where the two disagree, v8 wins.*

---

## 1. Scope

Native SwiftUI + SpriteKit port of `dead_mall_tycoon_v8.html`. iPad-only, iOS 17+. No iPhone, no Mac Catalyst.

The v8 prototype is the source of truth for **game logic, mechanics, economy, and feel**. It is **not** the source of truth for UI chrome or visual style — those are being rebuilt native. Every ported function carries a `// v8: <name>` comment so debugging can cross-reference.

---

## 2. State flow

Single source of truth: `GameState` — a plain Swift `struct` (value type) holding everything that currently lives on the v8 `G` object.

```
 ┌────────────────────────┐
 │  GameViewModel         │   @Observable — the only thing SwiftUI and
 │  (owns GameState)      │   SpriteKit observe.
 └───────┬────────────────┘
         │
         │ player action dispatch
         ▼
 ┌────────────────────────┐      pure, deterministic
 │  TickEngine.tick(      │ ◄──  (RNG injected, no global
 │    state, rng          │       Math.random())
 │  ) -> GameState        │
 └────────────────────────┘
         │
         │ new state assigned back
         ▼
 ┌────────────────────────┐       ┌─────────────────────┐
 │  SwiftUI views         │       │  SpriteKit MallScene│
 │  (HUD, tabs, sheets)   │       │  (corridor, sprites)│
 └────────────────────────┘       └─────────────────────┘
```

Key rule: **`TickEngine.tick` is pure.** It takes `(GameState, inout RandomNumberGenerator) -> GameState`. No timers, no UIKit, no side effects. This is what lets Phase 2 tests run a simulated year without spinning up the app. v8's `tick()` reaches into globals freely; the Swift port doesn't.

Player actions (accept tenant, place decoration, toggle wing, etc.) also go through pure functions that take a state and return a new state. The `GameViewModel` is the only mutable seam.

---

## 3. Logic vs rendering split

| Concern | Lives in | Notes |
|---|---|---|
| Game rules, economy, events, threat | `Services/TickEngine` + `Services/*` | Pure functions. No UI imports. |
| State types | `Models/` | Value types. `Equatable` where cheap. |
| Static data tables | `Data/` | Ports of v8 `PERSONALITIES`, `P_WEIGHTS`, `DECORATION_TYPES`, `PROMOTIONS`, `AD_DEALS`, `TENANT_TARGETS_ALL`, `STARTING_STORES`, `STARTING_DECORATIONS`, `STORE_POSITIONS`, tenant offer pools. |
| Observable wrapper | `ViewModels/GameViewModel` | `@Observable`. Owns the `GameState`, the active `Timer`/`DisplayLink` for tick cadence, and the RNG. |
| SwiftUI chrome | `Views/` | HUD, tab bar, decision sheets, tutorial, game-over. Reads VM, dispatches actions. Never mutates `GameState` directly. |
| Corridor scene | `Scenes/MallScene` | `SKScene`. Renders stores, decorations, visitors, thought bubbles. Reads VM; does not mutate. |

**Scene-model boundary:** `MallScene` gets a `weak var vm: GameViewModel?`. Every `SKSpriteNode` represents something in `GameState` by id. On state change, a diff pass reconciles nodes (add new, remove gone, update positions/textures). No per-frame state mutation happens in the scene.

---

## 4. SwiftUI ↔ SpriteKit bridge

```swift
struct MallSceneView: UIViewRepresentable {
    let vm: GameViewModel
    // wraps SKView hosting a single MallScene(size:)
}
```

Embedded in a SwiftUI `ZStack` with the HUD overlayed on top. The scene subscribes to state via `withObservationTracking` (iOS 17 observation) — when `vm.state` changes, the scene schedules a reconcile on the next SpriteKit update.

**Art pipeline.** Every visible node type (`VisitorNode`, `StoreNode`, `DecorationNode`, etc.) exposes a single texture-lookup function. Placeholder rectangles today, Christian's 128×128 pixel sprites later — one line change per node type to swap. No art is baked into logic paths.

---

## 5. Data model sketch

These are the core types that Phase 2 will implement. Fields mirror v8 `G` properties.

```swift
// Models/MallState.swift
enum MallState: String { case thriving, fading, struggling, dying, dead }
                                         // v8: getMallState()

// Models/ThreatBand.swift
enum ThreatBand { case stable, uneasy, risky, critical }
                                         // v8: getThreatBand()

// Models/Wing.swift
enum Wing: String { case north, south }

// Models/StoreTier.swift
enum StoreTier: String {
    case anchor, standard, kiosk, sketchy, vacant
}

// Models/Store.swift
struct Store: Identifiable {
    let id: Int                          // slot index, stable
    var name: String
    var tier: StoreTier
    var rent: Int
    var originalRent: Int
    var rentMultiplier: Double           // v8: adjustRent()
    var traffic: Int
    var threshold: Int
    var lease: Int                       // months remaining
    var hardship: Double                 // v8: s.hw
    var closing: Bool
    var leaving: Bool
    var monthsOccupied: Int
    var monthsVacant: Int
    var promotionActive: Bool
    let position: StorePosition          // x, y, w, h, wing — from STORE_POSITIONS
}

// Models/Decoration.swift
struct Decoration: Identifiable {
    let id: Int
    let type: DecorationType             // enum: kugel, fountain, plant, neon, bench, directory
    var x: Double
    var y: Double
    var condition: Int                   // 0..4 — v8 CONDITIONS
    var working: Bool
    var hazard: Bool
    var monthsAtCondition: Int
}

// Models/Visitor.swift
struct Visitor: Identifiable {
    let id: UUID
    let name: String
    let personality: PersonalityKey
    let type: VisitorType                // teen, adult, elder, kid
    let age: Int
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var speed: Double
    var target: VisitorTarget?
    var state: VisitorState              // entering, wandering, leaving
    var dwellTimer: Int
    var memory: String                   // last thought
}

// Models/TenantOffer.swift
struct TenantOffer {                     // v8: offerPool() results
    let name: String
    let tier: StoreTier
    let rent: Int
    let traffic: Int
    let threshold: Int
    let lease: Int
    let pitch: String
}

// Models/FlavorEvent.swift
struct FlavorEvent {                     // v8: buildEvents() + opening lawsuit
    let name: String
    let description: String
    let acceptLabel: String
    let declineLabel: String
    let onAccept: (inout GameState) -> Void
    let onDecline: (inout GameState, inout any RandomNumberGenerator) -> Void
}

// Models/GameState.swift — the root
struct GameState {
    // clock
    var month: Int                       // 0..11
    var year: Int                        // 1982+

    // money
    var cash: Int
    var debt: Int
    var score: Int
    var lastMonthlyScore: Int

    // world — visitors are NOT in GameState. They're scene-local in MallScene so 60fps
    // position writes don't churn the @Observable invalidation loop. Identity surfaces
    // to the VM via GameViewModel.selectVisitor(_ visitor: Visitor) on tap.
    var stores: [Store]
    var decorations: [Decoration]

    // operations
    var speed: Speed                     // paused, x1, x2, x4, x8
    var activePromos: [ActivePromotion]
    var activeAdDeals: [AdDeal]
    var activeStaff: StaffLoadout
    var wingsClosed: [Wing: Bool]
    var wingsDowngraded: [Wing: Bool]

    // meta
    var currentTab: Tab
    var threatMeter: Double              // 0..1
    var currentTraffic: Int
    var consecutiveLowTrafficMonths: Int
    var warnings: [Warning]
    var thoughtsLog: [ThoughtLogEntry]
    var gangMonths: Int
    var hazardFines: Int
    var pendingLawsuitMonth: Int?
    var decision: Decision?
    var gameover: Bool
    var started: Bool

    // selection (UI-adjacent but lives here for snapshot/undo)
    var selectedVisitorId: UUID?
    var selectedStoreId: Int?
    var selectedDecorationId: Int?

    // v9 additions (Phase 5)
    var scoreHistory: RingBuffer<Int>    // last 12 months — for sparkline
}
```

---

## 6. Timing & ticks

v8 runs two independent clocks:
- `setInterval(tick, ms)` — monthly economic tick.
- `requestAnimationFrame(animLoop)` — visitor motion, decoupled from `tick`.

The Swift port preserves that split:
- `GameViewModel` owns a `Timer` whose interval derives from `GameState.speed`. Each fire → `state = TickEngine.tick(state, rng: &rng)`.
- `MallScene` owns its own `update(_:)` frame loop for visitor motion (port of v8 `updateVisitorPositions()`). Visitor positions are treated as presentation state written back into `GameState` on a throttle — not every frame — so ticks see current positions without a tight coupling.

Speed toggle (paused / 1× / 2× / 4× / 8×) maps to v8 tick intervals: `[nil, 4000, 2000, 1000, 500]` ms.

---

## 7. v9 extension points (hooks in Phase 5)

Called out now so Phase 2 builds them in the right places:

- **Progressive year multiplier** (`monthlyScore`). v8 uses `1 + min(yr * 0.12, 3)`. Phase 5 replaces this with an uncapped curve that hits ~1× at y1, 3× at y5, 8× at y10, 15× at y15, 25× at y20. Implement as a single pure function `yearMultiplier(yearsElapsed: Double) -> Double` in `Services/Scoring.swift` so it's swappable and testable in isolation.
- **Ghost Mall visitor unlocks.** Phase 2 ports the v8 `P_WEIGHTS` table verbatim. Phase 5 adds a secondary `P_WEIGHTS_GHOST` table activated when `year >= 1987 (y5) && mallState ∈ [struggling, dying, dead]`. `PersonalityPicker.weightedPick(state:, year:)` reads both. New types (paranormal investigators, urbex pilgrims from out of state, fashion photographers) get their own thought pools — they shouldn't reuse the base personalities' lines.
- **Score velocity sparkline.** `GameState.scoreHistory` is a 12-slot ring buffer, appended each tick with `lastMonthlyScore`. `Views/HUD` renders it as a small inline `Canvas`-based sparkline next to the score value.

---

## 8. What Phase 1 does not include

No ported logic. No static data. No UI beyond `@main` + an empty `ContentView`. No tests. No asset catalog. Those land in Phases 2–5 in order.
