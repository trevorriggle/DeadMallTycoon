# Dead Mall Tycoon — Tuning Constants

Single source of truth for every numeric constant that affects gameplay feel.
Update as part of any prompt that introduces or modifies a tunable value.

## Scoring

- `ScoringTuning.baseVacancyRate = 2.0` — vacancy:memory ratio lever. Target 65:35 to 75:25 vacancy-favored at month 36. Raise if memory dominates; lower if memory is invisible. (Prompt 5)
- `Artifact.decayMultiplier` — curve: `1.0 + condition × 0.25`, clamped [1.0, 2.0]. Amplifies memoryScore as artifacts decay. (Prompt 5)

## Memory weight

- `ThoughtTuning.memoryWeightBaseIncrement = 0.25` — base weight per thought fire. (Prompt 4; halved 0.5 → 0.25 in v9 base-tick patch to keep memory-per-game-month constant after 1x tick doubled from 4000ms → 8000ms. See "Tick interval" below.)
- `ThoughtTuning.artifactProximityRadius = 40` — pts; visitor must be within this radius of an artifact for a thought to tag it. (Prompt 4)
- Cohort multipliers: Originals ×2.5, Nostalgics ×1.5, Explorers ×1.0. (Prompt 4)
- `MemoryWeight.visualThreshold = 5.0` — weight above which the pulse halo appears. (Prompt 4)

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
