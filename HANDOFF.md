# Dead Mall Tycoon — Port Handoff Notes

Hand-off from the Linux-codespace scaffold to Mac testing. Written at the end of the initial port pass (v8 HTML → SwiftUI + SpriteKit). Ordered for scanning — compile concerns first, UX second, architecture last.

---

## What shipped

| Phase | Commit | Contents |
|---|---|---|
| 1 | `2ca26b1` | Project scaffold, `project.yml` (XcodeGen), `ARCHITECTURE.md`, folder layout |
| 2 | `cc3985d` | `GameState`, `TickEngine`, all data tables, all pure services, `GameViewModel`, XCTest sanity tests |
| 3+4+5 | `0a1e761` | SpriteKit scene (procedural textures, store/decoration/visitor nodes, visitor motion), full SwiftUI UI (HUD, tabs, decision banner, start/tutorial/game-over screens), v9 additions (progressive year curve, Ghost Mall unlocks, score sparkline) |

**Totals:** 37 Swift files, 5,185 lines. Every ported function carries a `// v8: <name>` comment for cross-reference.

---

## To run on Mac

Clone the repo, open `DeadMallTycoon/DeadMallTycoon.xcodeproj`, ⌘R on an iPad simulator. The project and shared scheme are checked in — no generator step, no setup.

### Run tests

⌘U in Xcode. Or from terminal:

```bash
xcodebuild test -scheme DeadMallTycoon \
  -destination 'platform=iOS Simulator,name=iPad (11th generation)'
```

---

## Integration points verified (grep-audited)

- `yearMultiplier` has exactly one caller (`Scoring.monthlyScore`); v9 swap is self-contained.
- `PersonalityPicker.weightedPick` signature change propagated to all callers (`VisitorFactory.spawn`, 6 tests). No orphan call sites.
- `state.visitors` removal clean: the only remaining `visitors` hit is a v8-reference comment in `Visitor.swift`. Scene owns visitors; VM's `selectVisitor(_:)` takes a `Visitor` handed up from the scene on tap.
- `scoreHistory`: appended in `TickEngine.tick` (line 123), consumed by `HUDView.ScoreSparklineView`. Wire intact.
- `placingDecoration`: `vm.beginPlacement` → state flag → scene's `touchesEnded` → `vm.placeDecoration` → `DecorationActions.place` → clears flag.
- Decision flow: `tick` sets `state.decision + state.paused = true` → `DecisionBanner` renders at ContentView level so it's visible across tabs → `acceptDecision/declineDecision` dispatches through services → state cleared, tick resumes.
- Observation: `MallScene.observeAndReconcile()` re-registers on every change. Touches `started/gameover` so restart transitions flush scene-local visitor state.
- Ghost Mall gate: year ≥ startingYear+5 AND state ∈ {struggling, dying, dead}. Tests confirm pre-year-5 gate AND thriving-late gate both hold.

---

## Concerns for Mac testing

### Compilation risk (I couldn't build on Linux)

5,185 lines of Swift, zero compilation verification. Likeliest culprits if it won't build:

1. `@Observable` + `@State var vm = GameViewModel()` — iOS 17 pattern, should work, but I haven't seen it compile.
2. `UnevenRoundedRectangle(cornerRadii: .init(...))` in `TabBar` — iOS 16.4+, fine for target, but easy to typo.
3. `extension RandomNumberGenerator` with `mutating` methods using `&self` — canonical but occasionally has generic/existential friction.
4. `withObservationTracking` expects properties on an `@Observable` class. Access to `vm.state.stores` etc. registers because `vm.state` is the observable property. Should work but documentation is thin.

When you hit compile errors, send me the first few — these numbered items are where I'd start scanning.

### Visual / UX concerns

1. **Visitors are 10×14 px** — direct port of v8. On retina iPad they may be hard to tap. Fix: invisible `SKShapeNode` overlay around each `VisitorNode` for a larger hit area. Low priority until you feel it.
2. **Tab switching layout** — `MallView` kept alive via `.opacity()` so the SpriteKit scene isn't torn down. `MallView` (scene + panels) is taller than `OpsTabsView` (520 px). In the `ZStack` they may not align perfectly.
3. **Dim filter approximation** — v8 uses CSS `filter: brightness() saturate()` per abandonment level. I approximate with `colorBlendFactor` tinting. Visually close, not identical. Upgrade to `SKEffectNode` + `CIColorControls` later if desired.
4. **Store sign labels** — v8 drew a cream-colored rectangle *behind* the sign text. I render text directly on the tier color. Legibility is probably fine but not pixel-perfect.
5. **Visitor count in left panel** shows `"—"` — I couldn't wire a live count from the scene to the panel without reintroducing state churn. Trivial to add later via a lightweight `visitorCount: Int` on the VM that the scene writes only on spawn/despawn.

### Architectural concerns

1. **Observation reconcile storms** — every state change re-runs reconcile. For normal play (tick every 500–4000 ms) this is cheap. Rapid HUD interactions (rent ±, tab switch) run reconcile many times per second. SpriteKit diffing is cheap; not a correctness concern. Profile on device if it feels sticky.
2. **Restart flush is heuristic** — `handleLifecycleTransition` uses last-flag comparison to detect restart. If the VM ever sets `started = false` without setting it true again, flush won't re-trigger. Current restart flow is safe; brittle if the state machine grows. Cleaner design: expose `MallScene.flush()` and have VM call it explicitly on restart.
3. **Scene-local visitor RNG is un-seeded across sessions** — each run gets a random seed. Fine for gameplay but the visitor stream isn't reproducible even if the VM's tick RNG is.

### Behavior divergences from v8 (intentional)

- v9 year multiplier is far steeper at long tails; year-20 runs score ~6× higher than v8 would have.
- Ghost Mall adds 3 personalities not in v8 (Paranormal Investigator, Urbex Pilgrim, Fashion Photographer) with ~30 new thought lines. Gated at year 5+ and mall state struggling-or-worse.
- Score sparkline is net-new UI in the HUD (last 12 months of monthly-score accrual, colored by slope).

### What's NOT ported (intentional — not in v8 either)

- Cutaway dialogue scenes
- Wing macro view for level 3+ malls
- Level progression beyond level 1
- Save / restore persistence
- Sound effects

---

## Where the seams are

If a bug surfaces, these are the load-bearing files in order of fragility:

1. `Sources/Services/TickEngine.swift` — the entire economic simulation. If numbers feel wrong, read this against v8's `tick()` side-by-side.
2. `Sources/Scenes/MallScene.swift` — observation, reconciliation, visitor motion, touch routing. Most complex file in the port.
3. `Sources/ViewModels/GameViewModel.swift` — the only seam between pure logic and rendering. If the scene and UI disagree, it's probably this.
4. `Sources/Services/EventDeck.swift` — event apply-choice switch. If events misfire after accept/decline, read this.
5. `Sources/Data/Personalities.swift` — weighted tables. If visitor variety feels off, check weights here.

---

*Generated at end of initial port pass. Supersede or delete when Mac testing completes.*
