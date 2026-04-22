import SwiftUI

// v9 Prompt 6 — ClosureEventCard.
//
// Full-width overlay card surfacing a named tenant loss. Mounts into MallView
// as an overlay layer, so it obeys the Phase 0 invariant from Prompt 4: the
// mall scene and HUD do not shift when a card appears or dismisses.
//
// - Silent queue: consumes `pendingClosureEvents.first`. The Continue button
//   shows an "N pending" badge when the queue depth > 1.
// - Does NOT pause the game. Time continues; the card persists until tapped.
// - Anchor closures get a taller card frame to accommodate the longer
//   (two-to-three sentence) flavor line per Prompt 6 spec.
// - Uses the authored pixel-art tile Image("Closed") — the hand-made asset
//   in Assets.xcassets/Closed.imageset. Do NOT swap in any procedural
//   overlay; the Prompt-2 procedural never rendered correctly.
struct ClosureEventCard: View {
    @Bindable var vm: GameViewModel
    let event: ClosureEvent

    private var queueDepth: Int { vm.state.pendingClosureEvents.count }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            cardBody
                .frame(maxWidth: event.isAnchor ? 620 : 520)
                .padding(.horizontal, 24)
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.55).ignoresSafeArea())
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            flavorLine
            mechanicalConsequence
            continueButton
        }
        .padding(20)
        .background(Color(hex: "#14141a"))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(hex: "#8a2a6a"), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.7), radius: 20, y: 6)
    }

    // MARK: Header — thumbnail + name + kicker

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("Closed")
                .interpolation(.none)   // pixel art — preserve the original pixels
                .resizable()
                .scaledToFit()
                .frame(width: event.isAnchor ? 72 : 56,
                       height: event.isAnchor ? 72 : 56)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color(hex: "#3a3a48"), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.isAnchor ? "ANCHOR CLOSED" : "TENANT CLOSED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color(hex: "#ff4dbd"))
                Text(event.tenantName)
                    .font(.system(size: event.isAnchor ? 32 : 26,
                                  weight: .black, design: .serif))
                    .foregroundStyle(Color(hex: "#b8e8f8"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(datelineText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: "#6a6a78"))
            }
            Spacer(minLength: 0)
        }
    }

    // Authored flavor line — or the "[flavor line pending]" placeholder if
    // this tenant's entry hasn't been written yet. Either way, legible.
    private var flavorLine: some View {
        Text(ClosureFlavor.line(for: event))
            .font(.system(size: event.isAnchor ? 19 : 17, design: .serif))
            .italic()
            .foregroundStyle(Color(hex: "#d8d8e0"))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // Hard-coded consequence line (not authored). Two facts the game
    // contributes regardless of retailer: vacancy goes up, a memorial
    // artifact remains. Kept factual and tight.
    private var mechanicalConsequence: some View {
        HStack(spacing: 10) {
            Text("+ VACANCY SCORE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#ffd477"))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .overlay(RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color(hex: "#8a6a2a"), lineWidth: 1))
            Text("A MEMORIAL ARTIFACT REMAINS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#7fd3f0"))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .overlay(RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color(hex: "#2a6a8a"), lineWidth: 1))
            Spacer(minLength: 0)
        }
    }

    private var continueButton: some View {
        Button(action: { vm.dismissClosureEvent() }) {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .tracking(1)
                if queueDepth > 1 {
                    Text("\(queueDepth - 1) pending")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(hex: "#2a0a2a"))
                        .overlay(RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Color(hex: "#5a2a4a"), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(Color(hex: "#ff4dbd"))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .foregroundStyle(Color(hex: "#2a0a2a"))
            .background(Color(hex: "#ff4dbd"))
            .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color(hex: "#5a2a4a"), lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private var datelineText: String {
        // Zero-indexed month per GameState convention. Render as "Month N, Year".
        let m = event.month + 1
        let years = event.yearsOpen == 1 ? "1 year" : "\(event.yearsOpen) years"
        return "Month \(m), \(event.year) · open \(years)"
    }
}
