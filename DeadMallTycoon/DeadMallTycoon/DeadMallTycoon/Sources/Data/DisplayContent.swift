import Foundation

// v9 Prompt 7 — display content taxonomy.
//
// A displaySpace artifact carries one DisplayContent variant, chosen at
// conversion time in GameViewModel.repurposeAsDisplay via seeded rng.
// The variant drives:
//   - `thoughtPool`: per-variant lines that become the artifact's
//     thoughtTriggers, flavoring what visitors remember.
//   - `tintHex`: the rendered tint color for the procedural display-window
//     treatment (no authored asset yet).
//   - `displayName`: inspector label.
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
    // field at conversion time.
    var thoughtPool: [String] {
        switch self {
        // v9 Prompt 20 — three lines per variant, Explorer → Nostalgic →
        // Original per the cohort pool convention.
        case .vintageMallPhotos:
            return [
                "\"Look at those haircuts.\"",
                "\"That's the fountain when it worked. My family's in the background of the third one.\"",
                "\"I brought my kids here the day it opened. The fountain worked then.\"",
            ]
        case .communityArt:
            return [
                "\"My cousin's kid made one of those.\"",
                "\"The art class used to set up in the center court every spring.\"",
                "\"The first director insisted on local art in the windows. She was right.\"",
            ]
        case .seasonalVignette:
            return [
                "\"Nice they kept this up.\"",
                "\"Reminds me of the window displays at Halvorsen. Used to stop me cold.\"",
                "\"Whoever set this up remembers how these windows used to look. You can tell.\"",
            ]
        case .historicalPlaque:
            return [
                "\"Opened 1982. Huh.\"",
                "\"I didn't know the mayor cut the ribbon.\"",
                "\"I was at that ceremony. Forty below that January and they held it outside anyway.\"",
            ]
        case .localArtistShowcase:
            return [
                "\"These are pretty good.\"",
                "\"I went to high school with the person on the placard.\"",
                "\"They're showing the same woman they featured in '84. She still lives on Orchard.\"",
            ]
        }
    }
}
