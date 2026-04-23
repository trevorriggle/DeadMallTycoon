import SwiftUI

// v9 Prompt 9 Phase B — single ledger entry, rendered as one line of text
// via LedgerTemplates.line(for:). Presentational only; no tap handler in
// Phase B (Phase C will wrap this in a Button or add .onTapGesture to
// wire tap-to-highlight on the scene).
//
// Shared between the History tab (ManageDrawer) and the end-screen ledger
// (GameOverView) so both surfaces render entries identically — same font,
// same leading, same wrapping behavior.
struct LedgerEntryRow: View {
    let entry: LedgerEntry

    var body: some View {
        Text(LedgerTemplates.line(for: entry))
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(Color(hex: "#e8e8f0"))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
