import SwiftUI

// v9 Prompt 18 Phase B — tutorial beat modal card.
//
// Presents one TutorialBeat at a time — triggered by
// TutorialBeatDetector.scan (tick-based) or direct fireBeat calls
// (UI-triggered). Mounted in MallView's ZStack gated on
// `state.decision == nil && state.anchorDepartureCardQueue.isEmpty
// && state.activeTutorialBeat != nil` — so tenant-offer decisions and
// anchor cascade cards take precedence; the beat card waits behind
// them until both surfaces clear. The queue in
// state.tutorialBeatQueue handles the case where the detector fires
// multiple beats in a single tick (uncommon, but serializable).
//
// Pause composition mirrors AnchorDepartureCardView: fireBeat claims
// the pause iff nothing else holds it, dismissTutorialBeat releases
// only if this card owned the claim. Hand-off means a decision or
// anchor card pause survives the beat's dismiss intact.
struct TutorialBeatCard: View {
    @Bindable var vm: GameViewModel
    let beat: TutorialBeat

    private var content: TutorialBeatCardContent {
        TutorialBeatCopy.content(for: beat)
    }

    var body: some View {
        ZStack {
            // Slightly less opaque than the anchor card — this is a
            // teaching moment, not the seismic narrative beat.
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                // Title — short, ALL CAPS. Matches the "WELCOME · JANUARY
                // 1982" / "TENANT OFFER · PAUSED" typography family.
                Text(content.title)
                    .scaledFont(size: 16, weight: .black, design: .monospaced)
                    .tracking(1.8)
                    .foregroundStyle(Color(hex: "#ff4dbd"))
                    .multilineTextAlignment(.center)

                // Body — two or three sentences of teaching prose.
                Text(content.body)
                    .scaledFont(size: 17, design: .default)
                    .foregroundStyle(Color(hex: "#b8e8f8"))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)

                // Continue — explicit dismissal. No tap-elsewhere path.
                Button(action: { vm.dismissTutorialBeat() }) {
                    Text("Continue")
                        .scaledFont(size: 16, weight: .bold, design: .monospaced)
                        .tracking(1.0)
                        .foregroundStyle(Color(hex: "#2a0a2a"))
                        .padding(.horizontal, 28).padding(.vertical, 10)
                        .background(Color(hex: "#ff4dbd"))
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color(hex: "#5a2a4a"), lineWidth: 2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Spacer()
            }
            // v9 Prompt 23 — scales with UI scale for cross-iPad fit.
            .scaledFrame(maxWidth: 520)
            .padding(.horizontal, 24)
        }
    }
}
