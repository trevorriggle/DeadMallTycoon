import SwiftUI

// v9 Prompt 21 Fix 4 — "The Bank has Noticed" warning card.
//
// Full-screen overlay fired once per run the first tick state.debt crosses
// FailureTuning.bankruptcyWarningThreshold ($20,000). Mounted in MallView's
// ZStack gated on `state.bankruptcyWarningPending`. Uses the same card
// infrastructure as AnchorDepartureCardView: claims pause on appear,
// single Acknowledge button dismisses.
//
// The latch (state.bankruptcyWarningShown) is set by TickEngine in the
// same tick that sets Pending, so even if the player pays down debt and
// crosses the threshold again, the warning does not re-fire. One teaching
// moment per run.
struct BankruptcyWarningCard: View {
    @Bindable var vm: GameViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.97).ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Text("THE BANK HAS NOTICED")
                    .scaledFont(size: 28, weight: .black, design: .monospaced)
                    .tracking(2.4)
                    .foregroundStyle(Color(hex: "#ff2f4a"))
                    .multilineTextAlignment(.center)

                Text("Your debt has reached $20,000.")
                    .scaledFont(size: 22, weight: .semibold, design: .default)
                    .foregroundStyle(Color(hex: "#b8e8f8"))
                    .multilineTextAlignment(.center)

                // Body copy — two sentences, plain prose. Matches the
                // HowToPlay / tutorial voice: direct, no melodrama.
                VStack(alignment: .leading, spacing: 10) {
                    Text("At $25,000 the bank forecloses and you lose the mall.")
                    Text("You can pay down debt from available cash at any time via the MANAGE drawer.")
                }
                .scaledFont(size: 15, design: .default)
                .foregroundStyle(Color(hex: "#d8d8e0"))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 440, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.top, 8)

                Divider()
                    .frame(width: 240)
                    .overlay(Color(hex: "#3a3a48"))
                    .padding(.vertical, 8)

                // Mechanical summary — keeps parity with the anchor
                // departure card's monospace bullet pattern.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current debt · $\(vm.state.debt)")
                    Text("Available cash · $\(vm.state.cash)")
                    Text("Ceiling · $25,000")
                }
                .scaledFont(size: 13, weight: .regular, design: .monospaced)
                .foregroundStyle(Color(hex: "#6a6a78"))

                Spacer()

                Button(action: { vm.dismissBankruptcyWarning() }) {
                    Text("Acknowledge")
                        .scaledFont(size: 18, weight: .bold, design: .monospaced)
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
            // v9 Prompt 23 — max width scales with UI scale so on iPad
            // Pro 13" the card body isn't marooned mid-screen and on
            // iPad mini the copy column doesn't overflow.
            .scaledFrame(maxWidth: 520)
            .padding(.horizontal, 24)
        }
        .onAppear { vm.claimBankruptcyWarningPause() }
    }
}
