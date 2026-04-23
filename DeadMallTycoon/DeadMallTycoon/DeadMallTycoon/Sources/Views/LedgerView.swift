import SwiftUI

// v9 Prompt 9 Phase B — shared ledger list view.
//
// Renders LedgerEntries grouped by year with a year header above each
// block of entries. Does NOT own a ScrollView — the caller decides (the
// ManageDrawer History tab lives inside the drawer's top-level ScrollView;
// GameOverView wraps this in its own ScrollView).
//
// Used by both the History tab and the end-screen ledger so the two
// surfaces stay identical. No tap interaction in Phase B; Phase C adds
// the tap-to-highlight wiring at the row level.
struct LedgerView: View {
    let entries: [LedgerEntry]

    // Optional empty-state line. Callers can customize to fit tone — the
    // History tab uses a neutral "no entries yet" message during early
    // game; the end-screen uses something more memorial.
    let emptyStateText: String

    init(entries: [LedgerEntry],
         emptyStateText: String = "No entries yet. The run has just begun.") {
        self.entries = entries
        self.emptyStateText = emptyStateText
    }

    var body: some View {
        if entries.isEmpty {
            Text(emptyStateText)
                .font(.system(size: 13, design: .monospaced)).italic()
                .foregroundStyle(Color(hex: "#6a6a78"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            let groups = LedgerGrouper.groupByYear(entries)
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    yearSection(group)
                }
            }
        }
    }

    @ViewBuilder private func yearSection(_ group: LedgerGrouper.YearGroup) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Year header — bold, accent-colored so the year breaks the
            // wall of monospaced entries visually without needing chrome.
            Text(String(group.year))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color(hex: "#7fd3f0"))
                .padding(.top, 12)
                .padding(.bottom, 4)

            // Entries under the year. Offset-as-id is fine for an
            // append-only log: existing indices are stable across mutation.
            ForEach(Array(group.entries.enumerated()), id: \.offset) { _, entry in
                LedgerEntryRow(entry: entry)
                    .padding(.vertical, 1)
            }
        }
    }
}
