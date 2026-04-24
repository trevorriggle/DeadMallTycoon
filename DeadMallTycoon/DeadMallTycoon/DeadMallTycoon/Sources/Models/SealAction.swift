import Foundation

// v9 Prompt 19 — the three things the player can seal.
//
// Prior to Prompt 19, memorial sealing was the only player-initiated seal
// (wired through state.pendingSealConfirmationArtifactId). Wing sealing
// existed but routed through vm.toggleWingClosed(wing) with no confirmation;
// entrance sealing had no player entry point at all (only TickEngine's
// auto-seal on struggling+).
//
// SealAction unifies all three into a single value carried through the
// confirmation flow (GameState.pendingSealAction, SealConfirmOverlay,
// GameViewModel.requestSeal / confirmSeal). Enough information for the
// preview card to render AND for confirmSeal to dispatch the right
// mutation — no additional lookups required at confirm time.
enum SealAction: Equatable, Codable {
    case wing(Wing)
    case entrance(EntranceCorner)
    case memorial(artifactId: Int)
}
