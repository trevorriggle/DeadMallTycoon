import Foundation

// v9 — auto-dismiss notification banner shown in the upper letterbox.
//
// Toasts replace the modal Continue-tap pattern from Prompt 6's
// ClosureEventCard. Player is made aware of the event without having to
// dismiss it; the ledger remains the durable record. Multiple toasts
// stack in the upper area; the view fades each one in, holds for
// `duration`, then fades out and removes via vm.dismissToast(id:).
//
// Owned by GameState (single source of truth) so events fired from
// pure functions (TickEngine, EventDeck.apply, TenantLifecycle.vacateSlot)
// can append to state directly without reaching into the view layer.
struct Toast: Equatable, Identifiable, Codable {
    let id: UUID
    let title: String
    let subtitle: String?     // optional second line; closure flavor lines live here
    let style: ToastStyle
    let duration: TimeInterval

    init(id: UUID = UUID(),
         title: String,
         subtitle: String? = nil,
         style: ToastStyle,
         duration: TimeInterval? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.duration = duration ?? style.defaultDuration
    }
}

enum ToastStyle: String, Codable, CaseIterable {
    // Small neutral notification. ~2.5s.
    case info
    // Wider, retailer-name-prominent. Used for tenant closures so a player
    // who isn't actively watching can still register the loss without a
    // modal interrupt. ~5s.
    case closure
    // Slight positive accent. Used when a decline-the-lawsuit RNG roll
    // goes in the player's favor. ~3s.
    case victory
    // Slight warning accent. Used when the same roll goes against them.
    // ~3.5s.
    case loss

    var defaultDuration: TimeInterval {
        switch self {
        case .info:    return 2.5
        case .closure: return 5.0
        case .victory: return 3.0
        case .loss:    return 3.5
        }
    }
}
