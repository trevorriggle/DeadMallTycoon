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

    // Single lookup. Every case returns a placeholder-but-legible string
    // containing the key fields so the ledger UI is readable before copy
    // lands. Authored prose replaces the right-hand strings one case at a
    // time without changing the switch structure.
    static func line(for entry: LedgerEntry) -> String {
        switch entry {

        case .closure(let ev):
            return "[ledger pending: \(ev.tenantName) closed after "
                 + "\(ev.yearsOpen)y — \(monthYear(ev.month, ev.year))]"

        case .offerDestruction(let oldName, let newName, let years,
                                _, _, let y, let m):
            return "[ledger pending: \(newName) replaced \(oldName) "
                 + "(boarded \(years)y) — \(monthYear(m, y))]"

        case .artifactSealed(let name, _, _, _, let y, let m):
            return "[ledger pending: \(name) sealed — \(monthYear(m, y))]"

        case .displayConversion(let name, let content, _, _, let y, let m):
            return "[ledger pending: \(name) became a "
                 + "\(content.rawValue) display — \(monthYear(m, y))]"

        case .displayReverted(let name, let content, _, _, let y, let m):
            return "[ledger pending: the \(content.rawValue) display at "
                 + "\(name) came down — \(monthYear(m, y))]"

        case .artifactCreated(_, let name, let type, _, let y, let m):
            return "[ledger pending: \(name) (\(type.rawValue)) placed "
                 + "— \(monthYear(m, y))]"

        case .decayTransition(_, let name, _, let from, let to, let y, let m):
            return "[ledger pending: \(name) \(conditionName(from)) → "
                 + "\(conditionName(to)) — \(monthYear(m, y))]"

        case .artifactDestroyed(_, let name, _, let reason, let y, let m):
            return "[ledger pending: \(name) lost (\(reason)) "
                 + "— \(monthYear(m, y))]"

        case .envTransition(let from, let to, let y, let m):
            return "[ledger pending: mall \(from.rawValue) → "
                 + "\(to.rawValue) — \(monthYear(m, y))]"

        case .anchorDeparture(let name, let wing, _,
                               let coincident, let years, _, let y, let m):
            let tail = coincident.isEmpty
                ? ""
                : " (also: \(coincident.joined(separator: ", ")))"
            return "[ledger pending: \(name) vacated the \(wing.rawValue) "
                 + "anchor after \(years)y\(tail) — \(monthYear(m, y))]"

        case .attentionMilestone(_, let name, _, let t, let y, let m):
            return "[ledger pending: \(name) thought of for the \(t)th "
                 + "time — \(monthYear(m, y))]"
        }
    }
}
