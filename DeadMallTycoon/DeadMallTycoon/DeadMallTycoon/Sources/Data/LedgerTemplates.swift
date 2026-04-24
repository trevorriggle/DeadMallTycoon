import Foundation

// v9 Prompt 9 Phase A — ledger line rendering templates.
//
// `LedgerTemplates.line(for:)` is the single function the History UI (Phase B)
// and end-screen (Phase B) will call to render any LedgerEntry. Every case
// currently returns a "[ledger line pending: ...]" placeholder with the
// relevant fields interpolated. The structure is legible — a reader can see
// what event fired and when — but the narrative voice is NOT authored yet.
//
// Claude Code does NOT write these. They are the narrative voice of the
// ledger — the closure memorial, anchor departure, and decay moments get
// their specific character here. See AUTHORING TODO below for the exact
// checklist. The pattern mirrors Data/ClosureFlavor.swift (same "placeholder
// is a legible signal, not a silent miss" convention).
//
// -----------------------------------------------------------------------------
// AUTHORING TODO — replace the "[ledger line pending]" bodies below with
// authored prose. Voice: memorial provenance. One sentence; past-tense,
// third-person ledger entry style. Each line interpolates the relevant
// fields (name, year, wing, threshold, condition names, etc.).
//
//   [ ] .closure(event:)                      — non-anchor tenant closure
//   [ ] .anchorDeparture(...)                 — anchor closure + cascade (up to 3 sentences)
//   [ ] .offerDestruction(...)                — memorial displaced by new tenant
//   [ ] .artifactSealed(...)                  — player sealed a memorial permanently
//   [ ] .displayConversion(...)               — player curated a memorial into a display
//   [ ] .displayReverted(...)                 — player reverted a display back to boarded
//   [ ] .artifactCreated(...)                 — new artifact entered the run
//   [ ] .decayTransition(...)                 — condition advanced one step
//   [ ] .artifactDestroyed(...)               — artifact removed (non-offer path)
//   [ ] .envTransition(from:to:)              — mall entered a new environmental era
//   [ ] .attentionMilestone(...)              — artifact hit a thought-count threshold
//   [ ] .nameInheritance(...)                 — new tenant takes a departed anchor's name (homage)
//
// When authoring, keep interpolated fields in the same positions so the
// tests in LedgerFoundationTests can continue to assert structure without
// coupling to specific word choices.
// -----------------------------------------------------------------------------
enum LedgerTemplates {

    // Shared month-year formatter. "March 1991" style. No Date/Formatter
    // dependency — deterministic string output so tests can assert exactly.
    static func monthYear(_ month: Int, _ year: Int) -> String {
        let names = ["January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
        let idx = min(max(0, month), 11)
        return "\(names[idx]) \(year)"
    }

    // Condition int → display name via the Condition enum. Defensive clamp
    // for out-of-range values (shouldn't happen; condition is 0..4 in
    // practice).
    static func conditionName(_ condition: Int) -> String {
        let clamped = max(0, min(4, condition))
        return Condition(rawValue: clamped)?.name ?? "Unknown"
    }

    // AUTHORING TODO: Trevor to audit and refine.
    // v9 Prompt 20 — scaffolding prose. Omniscient narrator, quiet and
    // direct. Single sentence per entry; past tense; interpolated fields
    // kept in the same positions the tests assert. Anchor departure runs
    // up to three sentences per the schema.
    static func line(for entry: LedgerEntry) -> String {
        switch entry {

        case .closure(let ev):
            let yearPhrase = ev.yearsOpen == 1 ? "a year" : "\(ev.yearsOpen) years"
            return "\(monthYear(ev.month, ev.year)). \(ev.tenantName) closed "
                 + "after \(yearPhrase). The lights stayed on for a week out of habit."

        case .offerDestruction(let oldName, let newName, let years,
                                _, _, let y, let m):
            let yearPhrase = years == 1 ? "a year" : "\(years) years"
            return "\(monthYear(m, y)). \(newName) signed the lease where "
                 + "\(oldName) had been boarded for \(yearPhrase). The memorial came down with the plywood."

        case .artifactSealed(let name, _, _, _, let y, let m):
            return "\(monthYear(m, y)). \(name) was sealed. Drywall, paint, and a clean corner where a doorway had been."

        case .displayConversion(let name, let content, _, _, let y, let m):
            return "\(monthYear(m, y)). \(name) became a "
                 + "\(content.displayName) display. Someone decided the space deserved curation."

        case .displayReverted(let name, let content, _, _, let y, let m):
            return "\(monthYear(m, y)). The \(content.displayName) display at "
                 + "\(name) was taken down. The window is boarded again."

        case .artifactCreated(_, let name, _, _, let y, let m):
            return "\(monthYear(m, y)). A \(name) was placed in the corridor. The first visitor walked past it without looking."

        case .decayTransition(_, let name, _, let from, let to, let y, let m):
            return "\(monthYear(m, y)). The \(name) slipped from "
                 + "\(conditionName(from).lowercased()) to \(conditionName(to).lowercased()). Nobody logged a work order."

        case .artifactDestroyed(_, let name, _, let reason, let y, let m):
            return "\(monthYear(m, y)). The \(name) was lost. \(reason)."

        case .envTransition(let from, let to, let y, let m):
            return "\(monthYear(m, y)). The mall crossed from \(from.rawValue) "
                 + "into \(to.rawValue). Nothing official was said."

        case .anchorDeparture(let name, let wing, _,
                               let coincident, let years, _, let y, let m):
            let yearPhrase = years == 1 ? "one year" : "\(years) years"
            let wingWord = wing.rawValue
            let base = "\(monthYear(m, y)). \(name) vacated the \(wingWord) anchor "
                     + "after \(yearPhrase). The lease ran, the staff went home, and the corridor "
                     + "by the entrance darkened one band before the rest of the mall noticed."
            if coincident.isEmpty {
                return base
            } else {
                let list = coincident.joined(separator: ", ")
                return base + " In the weeks that followed, \(list) closed behind them."
            }

        case .attentionMilestone(_, let name, _, let t, let y, let m):
            return "\(monthYear(m, y)). The \(name) was thought of for the "
                 + "\(t)th time. A visitor paused, remembered something specific, and walked on."

        case .nameInheritance(let newName, let anchorName, _, let y, let m):
            return "\(monthYear(m, y)). \(newName) opened on the old "
                 + "\(anchorName) footprint. They kept the name. They knew."
        }
    }
}
