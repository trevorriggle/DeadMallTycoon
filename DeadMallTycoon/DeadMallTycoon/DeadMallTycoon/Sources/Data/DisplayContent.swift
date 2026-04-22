import Foundation

// v9 Prompt 7 — display content taxonomy.
//
// A displaySpace artifact carries one DisplayContent variant, chosen at
// conversion time in GameViewModel.repurposeAsDisplay via seeded rng.
// The variant drives:
//   - `thoughtPool`: per-variant placeholder strings that become the
//     artifact's thoughtTriggers, flavoring what visitors remember.
//   - `tintHex`: the rendered tint color for the procedural display-window
//     treatment (no authored asset yet).
//   - `displayName`: inspector label.
//
// All thought-pool content ships as "[flavor line pending]" and needs
// authoring. Claude Code does NOT write these lines. See AUTHORING TODO
// below for the exact checklist.
//
// -----------------------------------------------------------------------------
// AUTHORING TODO — replace "[flavor line pending]" entries in each variant's
// thoughtPool. Voice: curated-memorial, first-person. Three lines per variant
// minimum; more is fine. See ClosureFlavor.swift for tone reference.
//
//   [ ] vintageMallPhotos       — thoughtPool (3 lines)
//   [ ] communityArt            — thoughtPool (3 lines)
//   [ ] seasonalVignette        — thoughtPool (3 lines)
//   [ ] historicalPlaque        — thoughtPool (3 lines)
//   [ ] localArtistShowcase     — thoughtPool (3 lines)
// -----------------------------------------------------------------------------
enum DisplayContent: String, Codable, CaseIterable, Equatable {
    case vintageMallPhotos
    case communityArt
    case seasonalVignette
    case historicalPlaque
    case localArtistShowcase

    var displayName: String {
        switch self {
        case .vintageMallPhotos:    return "Vintage Mall Photos"
        case .communityArt:         return "Community Art"
        case .seasonalVignette:     return "Seasonal Vignette"
        case .historicalPlaque:     return "Historical Plaque"
        case .localArtistShowcase:  return "Local Artist Showcase"
        }
    }

    // Render tint for the procedural display-window treatment. Each variant
    // gets a distinct palette cue so the inspector + scene read different
    // content types at a glance. Swap these for authored pixel art when
    // assets ship (follow the ClosureFlavor AUTHORING pattern).
    var tintHex: String {
        switch self {
        case .vintageMallPhotos:    return "#c8a56a"   // faded sepia
        case .communityArt:         return "#d47aae"   // pink-magenta
        case .seasonalVignette:     return "#6aa87d"   // green
        case .historicalPlaque:     return "#8a7a5a"   // brass
        case .localArtistShowcase:  return "#6a8ac0"   // cool blue
        }
    }

    // Thought triggers that get assigned to the Artifact.thoughtTriggers
    // field at conversion time. Placeholder entries are intentional; real
    // authoring per the TODO checklist above.
    var thoughtPool: [String] {
        switch self {
        case .vintageMallPhotos:
            return [
                "[flavor line pending — vintage mall photos 1]",
                "[flavor line pending — vintage mall photos 2]",
                "[flavor line pending — vintage mall photos 3]",
            ]
        case .communityArt:
            return [
                "[flavor line pending — community art 1]",
                "[flavor line pending — community art 2]",
                "[flavor line pending — community art 3]",
            ]
        case .seasonalVignette:
            return [
                "[flavor line pending — seasonal vignette 1]",
                "[flavor line pending — seasonal vignette 2]",
                "[flavor line pending — seasonal vignette 3]",
            ]
        case .historicalPlaque:
            return [
                "[flavor line pending — historical plaque 1]",
                "[flavor line pending — historical plaque 2]",
                "[flavor line pending — historical plaque 3]",
            ]
        case .localArtistShowcase:
            return [
                "[flavor line pending — local artist showcase 1]",
                "[flavor line pending — local artist showcase 2]",
                "[flavor line pending — local artist showcase 3]",
            ]
        }
    }
}
