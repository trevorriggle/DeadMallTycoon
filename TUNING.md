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

## Visual

- Halo pulse: ±8% alpha, ±3% scale, 3.5s period. (Prompt 4)
