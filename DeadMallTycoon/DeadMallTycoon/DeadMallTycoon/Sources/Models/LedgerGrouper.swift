import Foundation

// v9 Prompt 9 Phase B — year-grouping helper for the History tab and the
// end-screen ledger view. Both render entries partitioned by year, so the
// grouping lives here in the model layer as a pure function (testable,
// no SwiftUI dependency).
//
// state.ledger is append-only and written in tick order; TickEngine
// advances time monotonically forward. That means entries are already
// in chronological order in the common case, so this walks the array
// once and collapses consecutive same-year entries into a group. If a
// later entry carries an earlier year (shouldn't happen in production;
// defensive), it starts a new group — source order is preserved
// verbatim rather than re-sorted, because the ledger's shape IS the
// run's shape and we don't want to hide time-travel bugs.
enum LedgerGrouper {

    struct YearGroup: Equatable {
        let year: Int
        let entries: [LedgerEntry]
    }

    static func groupByYear(_ entries: [LedgerEntry]) -> [YearGroup] {
        var result: [YearGroup] = []
        for entry in entries {
            let y = entry.year
            if let last = result.last, last.year == y {
                // Append to the current year's group.
                result[result.count - 1] = YearGroup(
                    year: y,
                    entries: last.entries + [entry]
                )
            } else {
                result.append(YearGroup(year: y, entries: [entry]))
            }
        }
        return result
    }
}
