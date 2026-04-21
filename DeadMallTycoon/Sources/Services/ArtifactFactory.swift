import Foundation

// v9: Construction helpers for Artifact. No mechanics — creation only. Future
// prompts will add accumulation, decay, and consumption services alongside
// this one.
enum ArtifactFactory {

    // v9: Build an artifact with the caller-supplied id. Mirrors how Decoration
    // ids are assigned by callers (see DecorationActions.place).
    // Defaults: condition 0 (Pristine), memoryWeight 0.
    // thoughtTriggers default to the type's placeholder pool; callers may pass
    // overrides for event- or tenant-specific flavor.
    static func make(id: Int,
                     type: ArtifactType,
                     name: String,
                     origin: ArtifactOrigin,
                     yearCreated: Int,
                     thoughtTriggers: [String]? = nil) -> Artifact {
        Artifact(
            id: id,
            name: name,
            type: type,
            yearCreated: yearCreated,
            condition: 0,
            memoryWeight: 0,
            origin: origin,
            thoughtTriggers: thoughtTriggers ?? defaultThoughtTriggers(for: type)
        )
    }

    // v9: Placeholder thought pools. Intentionally obvious "[placeholder: ...]"
    // strings — the real thought content is the highest-leverage creative work
    // in the v9 sequence and is authored by hand in a later prompt. Do not
    // replace these with generated prose; that decision belongs to Trevor.
    static func defaultThoughtTriggers(for type: ArtifactType) -> [String] {
        switch type {
        case .boardedStorefront:
            return [
                "[placeholder: boarded storefront thought 1]",
                "[placeholder: boarded storefront thought 2]",
                "[placeholder: boarded storefront thought 3]",
            ]
        case .stoppedFountain:
            return [
                "[placeholder: stopped fountain thought 1]",
                "[placeholder: stopped fountain thought 2]",
                "[placeholder: stopped fountain thought 3]",
            ]
        case .sealedEntrance:
            return [
                "[placeholder: sealed entrance thought 1]",
                "[placeholder: sealed entrance thought 2]",
                "[placeholder: sealed entrance thought 3]",
            ]
        case .flickeringNeon:
            return [
                "[placeholder: flickering neon thought 1]",
                "[placeholder: flickering neon thought 2]",
                "[placeholder: flickering neon thought 3]",
            ]
        case .deterioratingSkylight:
            return [
                "[placeholder: deteriorating skylight thought 1]",
                "[placeholder: deteriorating skylight thought 2]",
                "[placeholder: deteriorating skylight thought 3]",
            ]
        case .emptyFoodCourt:
            return [
                "[placeholder: empty food court thought 1]",
                "[placeholder: empty food court thought 2]",
                "[placeholder: empty food court thought 3]",
            ]
        case .outdatedDirectory:
            return [
                "[placeholder: outdated directory thought 1]",
                "[placeholder: outdated directory thought 2]",
                "[placeholder: outdated directory thought 3]",
            ]
        case .ruinedKugelBall:
            return [
                "[placeholder: ruined kugel ball thought 1]",
                "[placeholder: ruined kugel ball thought 2]",
                "[placeholder: ruined kugel ball thought 3]",
            ]
        case .waterStainedCeiling:
            return [
                "[placeholder: water-stained ceiling thought 1]",
                "[placeholder: water-stained ceiling thought 2]",
                "[placeholder: water-stained ceiling thought 3]",
            ]
        case .custom:
            return [
                "[placeholder: custom artifact thought 1]",
                "[placeholder: custom artifact thought 2]",
                "[placeholder: custom artifact thought 3]",
            ]
        }
    }
}
