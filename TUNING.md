# Dead Mall Tycoon — Tuning Constants

Single source of truth for every numeric constant that affects gameplay feel.
Update as part of any prompt that introduces or modifies a tunable value.

## Scoring

- `ScoringTuning.baseVacancyRate = 2.0` — vacancy:memory ratio lever. Target 65:35 to 75:25 vacancy-favored at month 36. Raise if memory dominates; lower if memory is invisible. (Prompt 5)
- `Artifact.decayMultiplier` — curve: `1.0 + condition × 0.25`, clamped [1.0, 2.0]. Amplifies memoryScore as artifacts decay. (Prompt 5)

## Memory weight

- `ThoughtTuning.memoryWeightBaseIncrement = 0.5` — base weight per thought fire. (Prompt 4)
- `ThoughtTuning.artifactProximityRadius = 40` — pts; visitor must be within this radius of an artifact for a thought to tag it. (Prompt 4)
- Cohort multipliers: Originals ×2.5, Nostalgics ×1.5, Explorers ×1.0. (Prompt 4)
- `MemoryWeight.visualThreshold = 5.0` — weight above which the pulse halo appears. (Prompt 4)

## Thought cadence

- `MallScene.passiveThoughtMinInterval = 20` — seconds, min per-visitor cadence. (Prompt 4)
- `MallScene.passiveThoughtMaxInterval = 30` — seconds, max per-visitor cadence. (Prompt 4)

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

## Visual

- Halo pulse: ±8% alpha, ±3% scale, 3.5s period. (Prompt 4)
