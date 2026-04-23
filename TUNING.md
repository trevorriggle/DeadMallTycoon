# Dead Mall Tycoon — Tuning Constants

Single source of truth for every numeric constant that affects gameplay feel.
Update as part of any prompt that introduces or modifies a tunable value.

## Scoring

- `ScoringTuning.baseVacancyRate = 2.0` — vacancy:memory ratio lever. Target 65:35 to 75:25 vacancy-favored at month 36. Raise if memory dominates; lower if memory is invisible. (Prompt 5)
- `Artifact.decayMultiplier` — curve: `1.0 + condition × 0.25`, clamped [1.0, 2.0]. Amplifies memoryScore as artifacts decay. (Prompt 5)
- `ScoringTuning.stateMemoryMultiplier` — per-env-state multiplier on the memory substrate. Memory becomes more rewarded as the mall ages. (Prompt 13)
    | state | multiplier |
    |---|---|
    | thriving | 1.0 |
    | fading | 1.0 |
    | struggling | 1.2 |
    | dying | 1.5 |
    | dead | 1.8 |
    | ghostMall | 2.0 |
- `ScoringTuning.actionBurstBase = 50` — base value for curation action bursts. Actual burst = `Int(actionBurstBase × max(0, stateMemoryMultiplier − 1.0))`. Zero at thriving/fading, 10 / 25 / 40 / 50 at struggling / dying / dead / ghostMall. Bursts fire on `ArtifactActions.sealStorefront`, `.place`, and `.repurposeAsDisplay`. `revertToBoarded` is score-neutral (un-curation). (Prompt 13)
- `ScoringTuning.memoryDecayMonths = 6` — months an artifact can go without a thought before its `memoryWeight` begins to decay. Reset by `GameViewModel.recordThoughtFired`; incremented each tick by `TickEngine`. (Prompt 13)
- `ScoringTuning.memoryDecayRatePerMonth = 0.05` — multiplicative fractional loss per tick once decay kicks in. Weight asymptotes toward zero but never reaches it; halves roughly every 14 months of uninterrupted neglect. (Prompt 13)

**Gate split (Prompt 13)**: `Scoring.monthlyScore` evaluates vacancy and memory as separate substrates with different gates. Vacancy keeps the v5 strict gate (`activeTenants >= 2 AND currentTraffic >= 30`) — "can't coast on emptiness" emerges naturally as the mall shrinks past 2 tenants. Memory relaxes to `activeTenants >= 1` and bypasses the hard traffic gate (still damped by `lifeMult` at low traffic) so the ENDGAME fantasy works: one tenant remains, the mall still scores from accumulated memory. Fully empty mall (`activeTenants < 1`) returns 0 regardless of memory. See `Scoring.swift` design-note block for the full formula.

## Memory weight

- `ThoughtTuning.memoryWeightBaseIncrement = 0.25` — base weight per thought fire. (Prompt 4; halved 0.5 → 0.25 in v9 base-tick patch to keep memory-per-game-month constant after 1x tick doubled from 4000ms → 8000ms. See "Tick interval" below.)
- `ThoughtTuning.artifactProximityRadius = 40` — pts; visitor must be within this radius of an artifact for a thought to tag it. (Prompt 4)
- Cohort multipliers: Originals ×2.5, Nostalgics ×1.5, Explorers ×1.0. (Prompt 4)
- `MemoryWeight.visualThreshold = 5.0` — weight above which the pulse halo appears. (Prompt 4)

## Thought selection (Prompt 11)

Visitor thoughts draw from artifact-specific pools when the visitor is in proximity; otherwise fall back to the personality × state pool. Proximity is the ONLY gate — the Prompt 4 "25% generic fallback" coin flip is gone. The "generic thoughts become rarer as the mall ages" property emerges naturally from late-game mall density: more artifacts → more proximity matches → less fallback.

- **Per-cohort pool access** — older visitors see more of each artifact's `thoughtTriggers` pool. Accessed as the first N strings (prefix), so slices are nested: Explorers ⊆ Nostalgics ⊆ Originals.
    | cohort | fraction | 10-string pool |
    |---|---|---|
    | Explorers | 0.30 | first 3 |
    | Nostalgics | 0.60 | first 6 |
    | Originals | 1.00 | all 10 |
  Minimum one string for any non-empty pool (authorial convention: order thoughtTriggers universal → specific, so Explorers get the surface-level observations and Originals get the deep cuts at the tail).
- **Weighted pick by memory weight** — when multiple artifacts are in proximity, selection is weighted by `memoryWeightFloor + memoryWeight`. Higher-memory artifacts become more likely to surface thoughts. `ThoughtTuning.memoryWeightFloor = 1.0` keeps fresh (memoryWeight=0) artifacts reachable; at memoryWeight=99 the artifact is ~50× more likely to win than a fresh peer. Tunes the "memory compounds" bias.

## Thought cadence

- `MallScene.passiveThoughtMinInterval = 20` — seconds, min per-visitor cadence. (Prompt 4)
- `MallScene.passiveThoughtMaxInterval = 30` — seconds, max per-visitor cadence. (Prompt 4)
- Cadence is REAL-TIME (seconds), not game-time (months). When the base tick slows, visitors fire more thoughts per game-month; the halved `memoryWeightBaseIncrement` offsets this for memory weight, so the per-game-month memory accrual is preserved. Attention-milestone counts (raw, per real-time) are unaffected — a fountain hits its 100th thought at the same real-time second regardless of tick speed.

## Tick interval

- `Speed.tickIntervalMs` — milliseconds per in-game month at each speed. (v9 base-tick patch — doubled from the original v8 cadence of 4000/2000/1000/500ms. The slowdown is to let ambient life read as atmosphere rather than fast-forward.)
    | speed | ms/month |
    |---|---|
    | `paused` | nil (timer off) |
    | `x1` | 8000 |
    | `x2` | 4000 |
    | `x4` | 2000 |
    | `x8` | 1000 |
- Per-tick probabilities (decay, entrance sealing, hardship, lease decay) stay correct: they're `per game-month`, unchanged by the real-time duration of a month.
- Real-time cadence events (toast durations, halo pulse, fluorescent flicker, env tween, ghost blackout, focus pulse, isolation check) stay correct: they're `per real-time`, unchanged by tick speed.
- Tutorial override: **dropped** in v9 base-tick patch. The tutorial previously forced 8000ms during year 1 — but the new base 1x IS 8000ms, so the override had no remaining effect. `state.tickIntervalOverrideMs` still exists as a seam for future subsystems; currently always nil.

## Failure modes (Prompt 14)

Two coexisting failure paths. Bankruptcy is the existing economic trigger (`debt >= GameConstants.debtCeiling`); memory failure is the new memorial trigger (`FailureMode.shouldForget(_:)`). Bankruptcy takes precedence when both fire the same tick — economic collapse dominates memorial neglect.

- `FailureTuning.memoryFailureThreshold = 15.0` — total `memoryWeight` across all artifacts. Below this value the mall is "not remembered enough." A handful of weighted artifacts (few dozen weight total) keeps the mall above this floor indefinitely. Instantaneous check; no duration. Strict `<` boundary.
- `FailureTuning.trafficFloor = 15` — absolute value of `state.currentTraffic`. Below this counts as "below floor." Dead state's target visitor count is ~4 so this condition trips reliably at collapse; thriving's ~22+ keeps it dormant.
- `FailureTuning.trafficFloorMonths = 12` — consecutive months below `trafficFloor` required to open the sustained-low-traffic gate. One in-game year. Counter (`state.consecutiveMonthsBelowTrafficFloor`) resets cleanly to 0 on any tick meeting the floor — unlike the ratio-based `consecutiveLowTrafficMonths` which slow-decrements.
- `FailureTuning.deadOrGhostMonths = 24` — consecutive months in `.dead` (includes `.ghostMall`, which is a dead substate) required to open the sustained-collapse gate. Two in-game years. Counter is the existing `state.monthsInDeadState`, incremented in TickEngine step 9.25.

**The narrative dichotomy**: aggressive vacancy-maximizing runs tend toward bankruptcy (vacant-slot penalties + low rent spirals debt past the ceiling). Neglectful runs with full occupancy but no curation tend toward forgotten (no memorials spawned, thin visitor-thought accumulation, mall eventually collapses and drifts past the sustained-collapse gates). The player's values — vacant-and-memorial versus occupied-and-lively — determine which failure approaches.

## Decision-sheet pause

- `GameState.decisionSheetOwnedPause: Bool` — set when a decision sheet (MANAGE drawer or top-level Acquire sheet) claims the pause on open, cleared on close. (v9 patch)
- Pattern mirrors `tutorialOwnedPause`: a sheet opens → if nothing else has paused the game, claim the pause and set the flag. On close → if we owned it, release. If a tenant-offer decision or tutorial coachmark already owns the pause, the sheet hands off (flag stays false; closing the sheet does not resume).
- Ambient surfaces (visitor profile panel, artifact info card) do NOT pause. Only decision surfaces pause.

## Artifact conversions

- Memory accrual rate by artifact type — `ArtifactType.memoryAccrualRate`, applied on top of the cohort multiplier in `GameViewModel.recordThoughtFired`. Sealed spaces are less noticed; display spaces are curated and engage more. (Prompt 7)
    | type | rate |
    |---|---|
    | `boardedStorefront` | 1.0× (baseline) |
    | `sealedStorefront` | 0.5× |
    | `displaySpace` | 1.5× |
- Display maintenance cost = `$75/mo` per `displaySpace` artifact — `Economy.operatingCost`. Covers cleaning, lighting, occasional content refresh. Raise if display spaces feel too cheap to curate. (Prompt 7)
- Sealed vacancy relief: a vacant slot with a `sealedStorefront` artifact does NOT incur the $350/mo vacancy penalty — the space is walled off, not maintained. Implemented as a filter in `Economy.operatingCost`, not a separate constant. (Prompt 7)

## Music

- `EnvironmentTuning.musicVolume` — per-state music track volume, applied to AVAudioPlayer on the active music track. Inverse curve of `ambientHumVolume`: music descends from thriving to ghostMall while hum ascends. At `dying` they cross over (both 0.35). At `ghostMall`, hum is 3.75× music — per ENDGAME.md: "the fluorescent hum is louder than the music." (Prompt 11)
    | state | music | hum (cross-ref) |
    |---|---|---|
    | thriving | 0.80 | 0.05 |
    | fading | 0.65 | 0.10 |
    | struggling | 0.50 | 0.20 |
    | dying | 0.35 | 0.35 |
    | dead | 0.25 | 0.55 |
    | ghostMall | 0.20 | 0.75 |
- `MusicService.crossfadeDuration = 3.0` — seconds. Synced-start with env visual transition (`EnvironmentTuning.transitionDuration = 2.0`) but deliberately longer so audio settles slightly after visuals. (Prompt 11)
- Track pool location: `Sources/Resources/audio/music/<state>_state/*.{wav,mp3,m4a,aiff}`. `MusicService` enumerates via `Bundle.main.urls(forResourcesWithExtension:subdirectory:)` at init. New tracks drop in; no code change, no manifest.
- Track selection: on state change, random pick from destination pool with session memory reset ("always pick fresh on re-entry"). On track finish, random pick strictly avoiding the just-played track if any alternative exists. `setEnvironmentState` is idempotent — same-state calls are no-ops so reconcile churn can't interrupt playback.

## Camera

- `MallScene.cameraMinZoom = 1.0` — fit-all zoom (shows entire authored world 1200 × 1400). Matches the pre-camera `.aspectFit` rendering exactly; no pan available at this zoom (camera pins to world center).
- `MallScene.cameraMaxZoom = 2.5` — closest zoom-in, enough to read a single storefront's signage without losing corridor context.
- Pan clamping: camera viewport stays entirely within world bounds — no black overscroll past the mall edges.
- Gesture scope: UIPinchGestureRecognizer + UIPanGestureRecognizer attached to the SKView inside `MallSceneView`. HUD, toasts, drawer, coachmarks, overlays are SwiftUI layers above the SKView and never receive the gestures — they remain fully interactive regardless of camera state. Single-tap (tap-to-select visitors/stores/artifacts) continues to route through `MallScene.touchesEnded` because `cancelsTouchesInView = false` on both recognizers.

## Artifact sizes

- Per-type pixel dimensions live in `Data/Catalog.swift` via `ArtifactCatalog.info(_:).size`. Sizes are in world / CSS coords; scene renders `.aspectFit` to device.
- Landmark items (kugel ball, fountain, pay phone bank, arcade cabinet, photo booth, coin horse, conversation pit, benches, directory board) rescaled 1.4×–1.8× post-Prompt-9 so they read as monuments against the 100×90 storefront scale. Texture items (planter, terrazzo, brass railing, cracked tile) and ceiling items (skylight, flickering fluorescent, emergency exit sign, stale christmas, stained tile) unchanged — small is correct for those.

## Economy — endgame viability (Prompt 17)

Rebalancing that makes "one specialty tenant, aggressively sealed, many displays" a mechanically reachable steady-state.

- `Economy.sealedWingSavings = 4500` — monthly ops savings per sealed wing (HVAC shutdown, security cut, lighting, cleaning contract, insurance). Raised from the v5 2500 after dying-mall viability audit showed savings were undervalued.
- `Economy.sealedEntranceSavings = 500` — monthly ops savings per sealed corner. Four corners sealed = $2,000/mo. Covers reduced security patrols, lighting, signage maintenance at closed entry points.
- `Economy.displayMaintenanceByState` — per-display-space maintenance, scaled by the mall's environmental state. Declining malls spend less on active curation (cleaning glass, refreshing content, lighting); displays become fossils.
    | state | per-display cost |
    |---|---|
    | thriving | 75 |
    | fading | 60 |
    | struggling | 45 |
    | dying | 30 |
    | dead | 20 |
    | ghostMall | 15 |
- `Economy.longTenureYearsThreshold = 10` / `Economy.longTenureRentMultiplier = 1.15` — tenants open 10+ consecutive years pay 15% more rent. Applied at rent-collection time in `Economy.rentByStore` so the Prompt 15 floating `+$N` indicator naturally shows the bumped amount; displayed `Store.rent` stays raw.
- **Most likely retune dial**: `sealedWingSavings`. If endgame feels too easy, drop to 4000; too hard, raise to 5000.

## Specialty tier + kiosk holdouts (Prompt 17)

Six-way `StoreTier` enum: `anchor / standard / kiosk / sketchy / specialty / vacant`. Specialty is a new professional-services tier; kiosk tier gains "quirky holdout" members via the `immuneToTrafficClosure` flag.

- `.specialty` tenants: Delaware Foot & Ankle, Beckett & Associates Tax Prep, Halvorsen Hearing Aid Center (homage), Delaware Allergy Partners, Crestwood Financial Advisors, The Delaware Business Library. Rent $2,500–$3,500, 48–60 month leases, threshold 5, traffic 10. All `immuneToTrafficClosure = true`.
- Kiosk holdouts (kiosk-tier, `immuneToTrafficClosure = true`): Auntie Rae's Pretzel Kiosk (starting mall seed, flagged), Sylvan Pay Phone Repair, Nails by Dora, Castle Key & Lock.
- Offer-pool mix per state: thriving 0 specialty/holdout (pure retail), fading 1, struggling 2, dying 3, dead 3 of the combined long-lived pool. Thriving is intentionally specialty-free — healthy retail pipeline leaves no room. Decline shifts the offer mix so services and quirky holdouts become the only takers.

**Immunity mechanism** (`Store.immuneToTrafficClosure: Bool`):
- TickEngine skips the traffic-based hardship bump (hardship still decays on the `else` branch so foreign accrual doesn't compound).
- Lease expiry auto-renews at 36 months instead of rolling the pressured-non-renewal RNG.
- Specialty & kiosk-holdout tenants don't leave due to low traffic, ever. Lease exhaustion (which shouldn't realistically happen given auto-renew) is the only exit path — matching ENDGAME.md's "one tenant, fourteen years."

## Halvorsen homage — name inheritance (Prompt 17)

Narrative beat without its own tuning constants. When a newly-signed tenant's name has a departed anchor name as prefix (e.g., "Halvorsen Hearing Aid Center" after the Halvorsen department store closed), `StoreActions.maybeRecordNameInheritance` emits a `.nameInheritance` ledger entry. Ledger tap focuses the anchor's memorial `boardedStorefront` (resolved by matching artifact.name against `inheritedFromAnchor`). One memoryWeight hook deliberately deferred for a later prompt — scope discipline.

## Anchor departure cascade

Triggered once per wing when that wing's anchor vacates (Prompt 10). All effects are permanent — the wing doesn't heal when/if re-tenanted.

- **Wing traffic multiplier**: `0.75` — in-wing non-anchor tenants treat mall-wide traffic as 75% for hardship calc. Scoped to the hardship comparison only; mall-wide `rawTraffic` and visitor motion are unaffected. Set in `state.wingTrafficMultipliers[wing]` by `TenantLifecycle.applyAnchorDepartureCascade`. (Prompt 10 Phase A)
- **Hardship stagger**: `3 months` — in-wing non-anchor tenants each receive `hardship += 1` on the next 3 consecutive ticks after anchor departure. Countdown in `state.pendingWingHardshipMonths[wing]`, consumed in `TickEngine` step 4.5 (after the main store loop, before artifact decay). Cascade-induced closings trip on the NEXT tick, reinforcing the staggered unraveling feel. (Prompt 10 Phase A)
- **Wing env-state offset**: `+1 band` — the wing's `EnvironmentState` drops one step toward `ghostMall` independently of the mall-wide state. Applied via `state.wingEnvOffsets[wing]`; resolved through `Mall.wingEnvironmentState(for:in:)`. Phase A ships the DATA only; scene rendering consumes this in Phase C. (Prompt 10 Phase A)
- **Cluster artifacts**: three ambient artifacts spawn in the wing alongside the `boardedStorefront` memorial. Positions are hand-picked per wing (deterministic; tests pin them) in `TenantLifecycle.clusterPositions`.
    | artifact | north wing | south wing |
    |---|---|---|
    | `stoppedEscalator` | (230, 260) | (930, 1140) |
    | `skylight` @ condition 3 | (550, 130) | (650, 1270) |
    | `lostSignage` | (270, 700) | (900, 700) |
- **Idempotency**: `state.anchorDepartedWings: Set<Wing>` flags fired cascades. Re-closing an anchor on a flagged wing does NOT re-fire the cascade — no double-cluster, no counter reset.

## Entrances

- Open-door traffic multiplier — applied in `Economy.entranceTrafficMultiplier(openEntranceCount:)`. Diminishing-returns curve; two open is the baseline that matches the pre-Prompt-6.5 two-wing layout, so rent / hardship tuning carries over unchanged. (Prompt 6.5)
    | open corners | multiplier |
    |---|---|
    | 0 | 0.0× (no new visitors spawn) |
    | 1 | 0.5× |
    | 2 | 1.0× (baseline) |
    | 3 | 1.2× |
    | 4 | 1.4× |
- Per-tick seal probability by mall state — `TickEngine` monthly roll picks a uniformly random open corner to seal. Each corner's individual seal rate is `p / openCount`. (Prompt 6.5, values carried over from pre-6.5 two-wing logic)
    | mall state | p |
    |---|---|
    | thriving / fading | 0.00 |
    | struggling | 0.05 |
    | dying | 0.10 |
    | dead | 0.15 |
- Topology: four corners — NW/NE → north wing, SW/SE → south wing. Wing closure hides both of its corners' doors; sealing is per-corner. (Prompt 6.5)

## Environmental visual

Six-state visual + audio state machine keyed to mall occupancy (plus a 60-month terminal "Ghost Mall" extension beyond `.dead`). All values live in `EnvironmentTuning`. Applied to the scene via `SKEffectNode + CIColorControls` (brightness + saturation) plus dedicated overlay nodes for flicker, blackout, and vignette. (Prompt 8)

- `EnvironmentTuning.brightnessMultipliers` — master scene brightness. Applied as `inputBrightness = multiplier - 1.0` on the CIColorControls filter (additive, range [-1, 1]; 0 = no change).
    | state | mult |
    |---|---|
    | thriving | 1.0 |
    | fading | 0.92 |
    | struggling | 0.8 |
    | dying | 0.65 |
    | dead | 0.5 |
    | ghostMall | 0.4 |
- `EnvironmentTuning.saturationMultipliers` — CIColorControls inputSaturation directly (1.0 = normal, 0.25 = near-monochrome).
    | state | mult |
    |---|---|
    | thriving | 1.0 |
    | fading | 0.85 |
    | struggling | 0.7 |
    | dying | 0.55 |
    | dead | 0.4 |
    | ghostMall | 0.25 |
- `EnvironmentTuning.fluorescentFlickerRate` — per-second probability of a corridor-wide flicker flash. Independent of the smooth state-transition tween (flicker runs on a separate overlay).
    | state | rate |
    |---|---|
    | thriving | 0.0 |
    | fading | 0.02 |
    | struggling | 0.08 |
    | dying | 0.2 |
    | dead | 0.35 |
    | ghostMall | 0.5 |
- `EnvironmentTuning.ambientHumVolume` — AVAudioPlayer volume for `fluorescentHum.wav`. Placeholder values pending actual audio files. At `ghostMall`, hum is intentionally louder than music (see ENDGAME.md).
    | state | vol |
    |---|---|
    | thriving | 0.05 |
    | fading | 0.10 |
    | struggling | 0.20 |
    | dying | 0.35 |
    | dead | 0.55 |
    | ghostMall | 0.75 |
- `EnvironmentTuning.isolationThreshold = 4` — corridor-visible visitors below this triggers the per-visitor shadow + desaturation treatment and the scene-wide edge vignette. (Prompt 8)
- `EnvironmentTuning.monthsInDeadForGhostMall = 60` — consecutive months in `.dead` required to enter `.ghostMall`. Counter resets on any recovery. (Prompt 8)
- `EnvironmentTuning.transitionDuration = 2.0` seconds — smooth tween on brightness + saturation + hum volume when `EnvironmentState` advances. Flicker/blackout are NOT tweened. (Prompt 8)
- `EnvironmentTuning.flickerFlashDuration = 0.06` seconds — single flicker flash length. (Prompt 8)
- `EnvironmentTuning.ghostMallBlackoutDuration = 0.4` / `ghostMallBlackoutCadence = 5.0` seconds — longer periodic full-corridor dimming, ghostMall-only, on top of the per-tick flicker. (Prompt 8)
- `EnvironmentTuning.decayAgeTierMonths = 24` months — decay overlay texture is regenerated when `(EnvironmentState, ageMonths / 24)` changes. A year-3 struggling mall and a year-15 struggling mall get materially different wear patterns. (Prompt 8)

## Ledger

- `LedgerEntry.attentionMilestoneThresholds = [10, 50, 100, 500, 1000]` — thoughtReferenceCount values that emit an `.attentionMilestone` ledger entry. Sparse, order-of-magnitude spacing so late-run artifacts (fountain, kugel) still produce legible beats without flooding the ledger. Each threshold fires at most once per artifact. (Prompt 9 Phase A)

## Visual

- Halo pulse: ±8% alpha, ±3% scale, 3.5s period. (Prompt 4)
