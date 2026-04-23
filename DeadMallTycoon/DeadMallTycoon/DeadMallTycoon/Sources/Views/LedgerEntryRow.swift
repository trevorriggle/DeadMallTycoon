import SwiftUI

// v9 Prompt 9 Phase B — single ledger entry, rendered as one line of text
// via LedgerTemplates.line(for:). Shared between the History tab (ManageDrawer)
// and the end-screen ledger (GameOverView) so both surfaces render entries
// identically — same font, same leading, same wrapping behavior.
//
// v9 Prompt 9 Phase C — optional tap. When `onTap` is non-nil AND the
// entry is `.isPotentiallyTappable`, the row wraps itself in a Button
// and renders a trailing chevron. Non-tappable entries (envTransition,
// offerDestruction, artifactDestroyed) render plain text regardless of
// whether `onTap` was passed — there's nothing to focus. Callers that
// want the whole list non-interactive pass `onTap = nil` (the default);
// the end-screen deliberately does this because the mall is frozen at
// game over and the focus pulse would be hidden under the opaque
// GameOverView anyway.
struct LedgerEntryRow: View {
    let entry: LedgerEntry
    let onTap: (() -> Void)?

    init(entry: LedgerEntry, onTap: (() -> Void)? = nil) {
        self.entry = entry
        self.onTap = onTap
    }

    private var isInteractive: Bool {
        onTap != nil && entry.isPotentiallyTappable
    }

    var body: some View {
        if isInteractive {
            Button(action: { onTap?() }) { rowContent }
                .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(LedgerTemplates.line(for: entry))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color(hex: "#e8e8f0"))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isInteractive {
                // Subtle chevron — signals tappability without stealing
                // visual weight from the entry text.
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "#6a6a78"))
            }
        }
        .contentShape(Rectangle())   // whole row is the hit target, not just the text
    }
}
