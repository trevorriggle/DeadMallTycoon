import SwiftUI

// v9 Prompt 10 Phase B — anchor departure modal card.
//
// Full-screen overlay presenting the seismic moment when an anchor
// tenant closes. Mounted in MallView's ZStack gated on
// `state.decision == nil && !state.anchorDepartureCardQueue.isEmpty` —
// so a tenant-offer decision active at the moment of an anchor cascade
// takes precedence; the anchor card waits behind it (one decision
// surface at a time, per spec).
//
// Pauses the game via vm.claimAnchorCardPause() on .onAppear (hands
// off gracefully if another subsystem already owns the pause). Only
// the explicit Continue button dismisses — no tap-anywhere-to-close,
// no drag-to-dismiss. This is a narrative beat the player has to
// acknowledge deliberately.
struct AnchorDepartureCardView: View {
    @Bindable var vm: GameViewModel
    let payload: AnchorDepartureCardPayload

    var body: some View {
        ZStack {
            // Opaque backdrop so the mall scene behind is visually
            // suppressed without being literally removed.
            Color.black.opacity(0.97).ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Anchor name — the emblematic word the run just lost.
                Text(payload.tenantName)
                    .font(.system(size: 48, weight: .black, design: .serif))
                    .foregroundStyle(Color(hex: "#b8e8f8"))
                    .multilineTextAlignment(.center)

                // Headline: "announces closure after N years."
                Text(headlineSuffix)
                    .font(.system(size: 20, design: .serif)).italic()
                    .foregroundStyle(Color(hex: "#d8d8e0"))

                // Authored flavor (2-3 sentences). Placeholder string
                // renders as-is until copy lands, matching the
                // ClosureFlavor / LedgerTemplates convention.
                Text(AnchorDepartureFlavor.line(for: payload.tenantName))
                    .font(.system(size: 15, design: .serif)).italic()
                    .foregroundStyle(Color(hex: "#c0c0cc"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)

                Divider()
                    .frame(width: 240)
                    .overlay(Color(hex: "#3a3a48"))
                    .padding(.vertical, 8)

                // Mechanical summary — what the player needs to know
                // about the wing after this card. Authored per-spec.
                VStack(alignment: .leading, spacing: 6) {
                    Text("The \(payload.wing.rawValue) wing darkens.")
                    Text("Traffic falls.")
                    Text("Neighboring tenants feel it.")
                }
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(Color(hex: "#6a6a78"))

                Spacer()

                // Continue — explicit, no tap-elsewhere path.
                Button(action: { vm.dismissAnchorDepartureCard() }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color(hex: "#2a0a2a"))
                        .padding(.horizontal, 32).padding(.vertical, 12)
                        .background(Color(hex: "#ff4dbd"))
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color(hex: "#5a2a4a"), lineWidth: 2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 40)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
        }
        .onAppear { vm.claimAnchorCardPause() }
    }

    private var headlineSuffix: String {
        let years = payload.yearsOpen
        let yearsPhrase = years == 1 ? "1 year" : "\(years) years"
        return "announces closure after \(yearsPhrase)."
    }
}
