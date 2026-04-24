import Foundation

// v9 Prompt 18 Phase A — tutorial beat card copy.
//
// TutorialBeatCopy.content(for:) is the single function the beat-card
// view (Views/TutorialBeatCard.swift) calls to render any beat. Every
// case currently returns a placeholder-but-legible body so the card is
// readable before Trevor authors the real copy. The structure — title,
// one or two sentences of lesson, Continue verb — is fixed; only the
// text inside changes during authoring.
//
// Claude Code does NOT write these. The tutorial voice is Trevor's —
// dry, present-tense, assumes intelligence, never explains the UI,
// only explains WHY a mechanic exists. See the AUTHORING TODO below
// for the checklist. Pattern mirrors Data/ClosureFlavor.swift and
// Data/LedgerTemplates.swift — placeholders are deliberately
// uninteresting so a missing auth is visible.
//
// -----------------------------------------------------------------------------
// AUTHORING TODO — replace the body strings below. Voice: Trevor's
// coach. Short. Specific. Never starts with "You are..." or "This is..."
// Each card is one title + one body paragraph. Body CAN run two
// sentences; three is the ceiling.
//
//   [ ] .welcome                       — paused welcome card (before Jan 1982)
//   [ ] .manageDrawer                  — first MANAGE drawer open
//   [ ] .firstPlacement                — first artifact placed from Acquire
//   [ ] .firstTenantOffer              — first tenant Decision banner
//   [ ] .firstClosure                  — first tenant closure
//   [ ] .firstVisitorThought           — first visitor-thought read
//   [ ] .firstLedgerView               — first History/ledger open
//   [ ] .firstSeal                     — first boardedStorefront sealed
//   [ ] .firstDisplay                  — first boardedStorefront → displaySpace
//   [ ] .firstBoardedStorefront        — first closure memorial on scene
//   [ ] .firstWingEligibleForSealing   — first wing drops below 50% occupancy
//   [ ] .firstSealCompleted            — first successful seal (any type)
//   [ ] .firstHazard                   — first hazard artifact on scene
//   [ ] .firstEnvTransition            — first env band crossed
//   [ ] .firstMallDying                — first .dying state
//   [ ] .firstSealedWingSaving         — first wing closure visible in ops
//   [ ] .firstActionBurst              — first non-zero actionBurst
//   [ ] .firstAnchorDeparture          — first anchor closure (before cascade card)
//   [ ] .firstSpecialtyOffer           — first specialty-tier offer
//   [ ] .firstMallDead                 — first .dead state
//   [ ] .approachingForgotten          — 3 months from forgotten trip
//   [ ] .firstGhostMall                — first .ghostMall state
//
// -----------------------------------------------------------------------------

struct TutorialBeatCardContent {
    let title: String
    let body: String
}

enum TutorialBeatCopy {

    static func content(for beat: TutorialBeat) -> TutorialBeatCardContent {
        switch beat {

        case .welcome:
            return TutorialBeatCardContent(
                title: "WELCOME · JANUARY 1982",
                body: "[tutorial pending: welcome — the game starts paused. A mall has been inherited. Decay is the goal; bankruptcy and being forgotten are both losses.]"
            )

        case .manageDrawer:
            return TutorialBeatCardContent(
                title: "MANAGE",
                body: "[tutorial pending: manageDrawer — the drawer is where rent, staff, wings, promotions, and ad deals live. Everything here is optional. Everything costs something.]"
            )

        case .firstPlacement:
            return TutorialBeatCardContent(
                title: "ARTIFACT PLACED",
                body: "[tutorial pending: firstPlacement — artifacts aren't decorations. They're things people remember. Condition decays over time; memory weight accrues when visitors think about them.]"
            )

        case .firstTenantOffer:
            return TutorialBeatCardContent(
                title: "A TENANT WANTS IN",
                body: "[tutorial pending: firstTenantOffer — signing adds rent but removes empty-storefront score. Declining keeps the vacancy. Both are valid; neither is free.]"
            )

        case .firstClosure:
            return TutorialBeatCardContent(
                title: "A STORE CLOSED",
                body: "[tutorial pending: firstClosure — the storefront stays. It's boarded up. Memorials accrue memory weight when visitors remember them.]"
            )

        case .firstVisitorThought:
            return TutorialBeatCardContent(
                title: "A VISITOR REMEMBERS",
                body: "[tutorial pending: firstVisitorThought — every visitor you tap fires a thought. Thoughts that reference an artifact add memory weight to it. That's how the mall stays remembered.]"
            )

        case .firstLedgerView:
            return TutorialBeatCardContent(
                title: "THE HISTORY",
                body: "[tutorial pending: firstLedgerView — this is the mall's memorial provenance. Every closure, every seal, every curation, every decay step. The end-of-run screen is this same list.]"
            )

        case .firstSeal:
            return TutorialBeatCardContent(
                title: "SEALED",
                body: "[tutorial pending: firstSeal — sealing preserves the memorial permanently at its current condition. Memory weight keeps accruing at half rate. Irreversible.]"
            )

        case .firstDisplay:
            return TutorialBeatCardContent(
                title: "CURATED",
                body: "[tutorial pending: firstDisplay — a display space is active curation. Memory weight accrues at 1.5× but it costs monthly maintenance. Revertible to boarded at any time.]"
            )

        case .firstHazard:
            return TutorialBeatCardContent(
                title: "HAZARD",
                body: "[tutorial pending: firstHazard — that artifact is hazardous. It accrues monthly fines until repaired or removed. Also raises threat.]"
            )

        case .firstEnvTransition:
            return TutorialBeatCardContent(
                title: "THE MALL HAS CHANGED",
                body: "[tutorial pending: firstEnvTransition — the mall moved between environmental states (thriving / fading / struggling / dying / dead / ghostMall). Each state changes scoring, costs, and visitor behavior.]"
            )

        case .firstMallDying:
            return TutorialBeatCardContent(
                title: "DYING",
                body: "[tutorial pending: firstMallDying — state .dying. Memory score multiplier rises; visitor counts fall. The game is now scoring well.]"
            )

        case .firstSealedWingSaving:
            return TutorialBeatCardContent(
                title: "A WING CLOSED ITSELF",
                body: "[tutorial pending: firstSealedWingSaving — closing a wing cuts $4,500/mo off operating costs. Sealing is an economic tool, not just a memorial verb.]"
            )

        case .firstActionBurst:
            return TutorialBeatCardContent(
                title: "ACTION BURST",
                body: "[tutorial pending: firstActionBurst — curation actions compound when the mall is struggling or worse. Seal, display, and place in quick succession for a score bonus.]"
            )

        case .firstAnchorDeparture:
            return TutorialBeatCardContent(
                title: "ANCHOR LEAVING",
                body: "[tutorial pending: firstAnchorDeparture — an anchor is closing. The wing will lose 25% traffic permanently and go one band darker than the mall. Neighbor tenants will cascade-close over 3 months. This is irreversible.]"
            )

        case .firstSpecialtyOffer:
            return TutorialBeatCardContent(
                title: "SPECIALTY TENANT",
                body: "[tutorial pending: firstSpecialtyOffer — specialty tenants are immune to traffic-based closures and pay rent on 3-5 year leases. They're the tenant that stays when the mall empties around them.]"
            )

        case .firstMallDead:
            return TutorialBeatCardContent(
                title: "DEAD",
                body: "[tutorial pending: firstMallDead — state .dead. Score multiplier is maxed. No new visitors spawn; only the regulars remain. The run is in late-game.]"
            )

        case .approachingForgotten:
            return TutorialBeatCardContent(
                title: "BEING FORGOTTEN",
                body: "[tutorial pending: approachingForgotten — the mall is close to the forgotten-failure trip. If traffic stays below floor and memory weight stays thin, the run ends. Curate, seal, or approach a specialty tenant to recover.]"
            )

        case .firstGhostMall:
            return TutorialBeatCardContent(
                title: "GHOST MALL",
                body: "[tutorial pending: firstGhostMall — state .ghostMall. Five consecutive years in dead. This is what the game exists to produce. Every month survived here is the highest-value month possible.]"
            )

        // v9 Prompt 19 — sealing legibility beats. Placeholder copy
        // captures the intent from the Prompt 19 spec (Trevor to author
        // the final voice). Each card teaches the SEAL button as the
        // primary surface and frames sealing as an economic tool.
        case .firstBoardedStorefront:
            return TutorialBeatCardContent(
                title: "A STOREFRONT IS EMPTY",
                body: "[tutorial pending: firstBoardedStorefront — a storefront closed. An empty slot costs $350/mo in vacancy penalty. Tap SEAL in the HUD to convert it to a memorial — no more cost, and visitors will remember it. Wings and entrances can also be sealed from there later.]"
            )

        case .firstWingEligibleForSealing:
            return TutorialBeatCardContent(
                title: "A WING IS MOSTLY EMPTY",
                body: "[tutorial pending: firstWingEligibleForSealing — a wing has dropped below half occupancy. Sealing it saves $4,500/mo and converts its empty space into memorial score. Tap SEAL to review the options.]"
            )

        case .firstSealCompleted:
            return TutorialBeatCardContent(
                title: "SEALED",
                body: "[tutorial pending: firstSealCompleted — saved money AND gained score. Sealing is the primary economic tool as the mall declines. The game rewards shrinking deliberately, not preventing decline.]"
            )
        }
    }
}
