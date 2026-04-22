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

## Visual

- Halo pulse: ±8% alpha, ±3% scale, 3.5s period. (Prompt 4)
