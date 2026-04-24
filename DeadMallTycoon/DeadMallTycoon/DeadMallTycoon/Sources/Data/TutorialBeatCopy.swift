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

// AUTHORING TODO: Trevor to audit and refine.
// v9 Prompt 20 — scaffolding copy. Warm, direct, slightly wry. Teaches the
// mechanic without performing. One or two sentences per beat. Final voice
// pass pending Trevor's audit.
enum TutorialBeatCopy {

    static func content(for beat: TutorialBeat) -> TutorialBeatCardContent {
        switch beat {

        case .welcome:
            return TutorialBeatCardContent(
                title: "WELCOME · JANUARY 1982",
                body: "You've inherited a mall. The goal isn't to save it. It's to let it become something. Bankruptcy is a loss. Being forgotten is the other one."
            )

        case .manageDrawer:
            return TutorialBeatCardContent(
                title: "MANAGE",
                body: "Rent, staff, wings, promotions, ad deals. Everything here is optional. Everything costs something."
            )

        case .firstPlacement:
            return TutorialBeatCardContent(
                title: "ARTIFACT PLACED",
                body: "Artifacts aren't decoration. They're things people remember. Their condition decays; their memory weight grows every time a visitor thinks about them."
            )

        case .firstTenantOffer:
            return TutorialBeatCardContent(
                title: "A TENANT WANTS IN",
                body: "Signing adds rent and loses the empty-storefront score. Declining keeps the vacancy. Both are valid moves. Neither is free."
            )

        case .firstClosure:
            return TutorialBeatCardContent(
                title: "A STORE CLOSED",
                body: "The storefront stays. It's boarded up now. Memorials accrue memory weight the same as any other artifact."
            )

        case .firstVisitorThought:
            return TutorialBeatCardContent(
                title: "A VISITOR REMEMBERS",
                body: "Tap visitors to read their thoughts. Thoughts that reference an artifact add memory weight to it. That's how the mall stays remembered."
            )

        case .firstLedgerView:
            return TutorialBeatCardContent(
                title: "THE HISTORY",
                body: "The ledger is the mall's memorial provenance. Every closure, every seal, every decay step. The end screen is this same list."
            )

        case .firstSeal:
            return TutorialBeatCardContent(
                title: "SEALED",
                body: "Sealing freezes a memorial at its current condition. Memory keeps accruing at half speed. You can't undo this."
            )

        case .firstDisplay:
            return TutorialBeatCardContent(
                title: "CURATED",
                body: "A display space is active curation. Memory accrues 1.5× but it costs monthly maintenance. You can revert it to boarded any time."
            )

        case .firstHazard:
            return TutorialBeatCardContent(
                title: "HAZARD",
                body: "That artifact is hazardous. It bleeds money in monthly fines and pushes threat up until you repair it or remove it."
            )

        case .firstEnvTransition:
            return TutorialBeatCardContent(
                title: "THE MALL HAS CHANGED",
                body: "The mall crossed into a new state. Scoring, costs, visitor mix, and tone all shift. The state bar up top is the most important number on screen now."
            )

        case .firstMallDying:
            return TutorialBeatCardContent(
                title: "DYING",
                body: "State is dying. Memory multiplier is up; visitor counts are down. This is when the game starts scoring in earnest."
            )

        case .firstSealedWingSaving:
            return TutorialBeatCardContent(
                title: "A WING CLOSED ITSELF",
                body: "Closing a wing cuts $4,500 off monthly operating costs. Sealing is an economic tool, not just a memorial verb."
            )

        case .firstActionBurst:
            return TutorialBeatCardContent(
                title: "ACTION BURST",
                body: "Curation actions compound when the mall is struggling or worse. Seal, curate, and place in quick succession to stack a burst bonus."
            )

        case .firstAnchorDeparture:
            return TutorialBeatCardContent(
                title: "ANCHOR LEAVING",
                body: "An anchor is closing. The wing loses a quarter of its traffic permanently and runs one band darker than the rest of the mall. Neighboring tenants will cascade-close over the next three months. You can't undo this."
            )

        case .firstSpecialtyOffer:
            return TutorialBeatCardContent(
                title: "SPECIALTY TENANT",
                body: "Specialty tenants are immune to traffic-based closure and lease for three to five years. They're the ones who stay when everything around them empties out."
            )

        case .firstMallDead:
            return TutorialBeatCardContent(
                title: "DEAD",
                body: "State is dead. Memory multiplier is maxed. No new visitors spawn; the ones who come now are the ones who come specifically because it's dead."
            )

        case .approachingForgotten:
            return TutorialBeatCardContent(
                title: "BEING FORGOTTEN",
                body: "The mall is close to the forgotten trip. Memory weight is thin and traffic has been under the floor for a year. Curate something, seal a slot, or sign a specialty tenant to pull out of it."
            )

        case .firstGhostMall:
            return TutorialBeatCardContent(
                title: "GHOST MALL",
                body: "Five consecutive years in dead. This is the mall the game exists to produce. Every month you survive here is the highest-value month possible."
            )

        // v9 Prompt 19 — sealing legibility beats.
        case .firstBoardedStorefront:
            return TutorialBeatCardContent(
                title: "A STOREFRONT IS EMPTY",
                body: "A storefront closed. An empty slot costs $350 a month in vacancy penalty. Tap SEAL in the HUD to convert it to a permanent memorial. No more cost, and visitors will remember it."
            )

        case .firstWingEligibleForSealing:
            return TutorialBeatCardContent(
                title: "A WING IS MOSTLY EMPTY",
                body: "A wing has dropped below half occupancy. Sealing it saves $4,500 a month and converts the empty space into memorial score. Tap SEAL to review the options."
            )

        case .firstSealCompleted:
            return TutorialBeatCardContent(
                title: "SEALED",
                body: "You saved money and gained score in one move. Sealing is the primary economic tool as the mall declines. The game rewards shrinking on purpose, not fighting the decline."
            )
        }
    }
}
