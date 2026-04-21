import Foundation

// v9: Artifacts are the primary memorial entity. Prompt 1 introduces the model
// only — Prompts 2+ wire it into tenant closure, decay, scoring, and visitor
// thoughts. Do not couple to mechanics in this file. If you are a future
// Claude Code session opening this file and wondering why nothing reads from
// GameState.artifacts, that is intentional: the staged rollout is model-first,
// consumers-later. Introducing mechanics here prematurely will conflict with
// subsequent prompts in the sequence.

// v9: Type taxonomy for artifacts. `custom` is an escape hatch for artifacts
// created by events or scripted content that don't fit a preset template —
// the display name lives on `Artifact.name`, not the enum.
enum ArtifactType: String, Codable, CaseIterable, Equatable {
    case boardedStorefront
    case stoppedFountain
    case sealedEntrance
    case flickeringNeon
    case deterioratingSkylight
    case emptyFoodCourt
    case outdatedDirectory
    case ruinedKugelBall
    case waterStainedCeiling
    case custom
}

// v9: Origin tracks what caused an artifact to exist. Kept as a three-case
// enum rather than a String so downstream prompts (e.g. anchor-ripple cascade
// artifact generation) can pattern-match without re-parsing strings.
enum ArtifactOrigin: Equatable, Codable {
    case tenant(name: String)
    case event(name: String)
    case playerAction(String)
}

// v9: The artifact itself. Condition is 0..4 and mirrors the existing
// Decoration condition scale. Memory weight starts at 0 and is intended to
// accumulate each month the artifact persists — the multiplier that will feed
// into scoring and visitor thought salience in later prompts.
struct Artifact: Identifiable, Equatable, Codable {
    let id: Int
    var name: String
    var type: ArtifactType
    var yearCreated: Int
    var condition: Int            // 0..4, parallel to Condition enum on Decoration
    var memoryWeight: Double      // starts at 0, accumulates later
    var origin: ArtifactOrigin
    var thoughtTriggers: [String] // pool specific to this artifact instance
}
