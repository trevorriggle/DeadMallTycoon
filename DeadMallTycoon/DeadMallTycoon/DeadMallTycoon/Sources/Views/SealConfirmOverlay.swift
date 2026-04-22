import SwiftUI

// v9 Prompt 7 — seal confirmation dialog.
//
// Mounted in MallView as a full overlay when GameState.pendingSealConfirmationArtifactId
// is non-nil. Obeys the Phase 0 overlay-only invariant from Prompt 4: the
// mall scene and HUD positions do not shift when this appears or dismisses.
//
// Copy is placeholder — marked `[copy pending]`. Real authoring per the
// ClosureFlavor pattern.
struct SealConfirmOverlay: View {
    @Bindable var vm: GameViewModel

    var body: some View {
        if let artifactId = vm.state.pendingSealConfirmationArtifactId,
           let artifact = vm.state.artifacts.first(where: { $0.id == artifactId }) {
            overlay(for: artifact)
        }
    }

    private func overlay(for a: Artifact) -> some View {
        VStack {
            Spacer()
            card(for: a)
                .frame(maxWidth: 480)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.55).ignoresSafeArea())
    }

    private func card(for a: Artifact) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SEAL THIS SPACE?")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(Color(hex: "#ff4dbd"))
            Text(a.name)
                .font(.system(size: 22, weight: .black, design: .serif))
                .foregroundStyle(Color(hex: "#b8e8f8"))
            Text("[copy pending — seal confirmation flavor]")
                .font(.system(size: 15, design: .serif))
                .italic()
                .foregroundStyle(Color(hex: "#d8d8e0"))
                .fixedSize(horizontal: false, vertical: true)
            Text("SEALING IS PERMANENT · NO RE-OPEN · MEMORY ACCRUAL DROPS TO 0.5×")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#ffd477"))
                .padding(.top, 2)
            HStack(spacing: 10) {
                Button("Cancel") { vm.cancelSealConfirmation() }
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(Color(hex: "#d8d8e0"))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color(hex: "#1a1a22"))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color(hex: "#3a3a48"), lineWidth: 1.5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .buttonStyle(.plain)
                Spacer(minLength: 0)
                Button("Seal Permanently") { vm.confirmSeal() }
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(Color(hex: "#2a0a2a"))
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Color(hex: "#ff4dbd"))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color(hex: "#5a2a4a"), lineWidth: 2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .buttonStyle(.plain)
            }
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
}
