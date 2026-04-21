import SwiftUI

// v9 Prompt 3 followup — standalone sheet launched from the top-level HUD
// Acquire button. Shows ArtifactAcquirePanel with a close header and medium
// detent (matches the MANAGE drawer's presentation style). Picking an artifact
// starts placement and dismisses the sheet so the player lands on the corridor.
struct ArtifactAcquireSheet: View {
    @Bindable var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#3a3a48"))
            ScrollView {
                ArtifactAcquirePanel(vm: vm) { type in
                    vm.beginPlacement(type)
                    dismiss()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .background(Color(hex: "#14141a"))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text("ACQUIRE")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(hex: "#b8e8f8"))
            Spacer()
            Button("Close") { dismiss() }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#6a6a78"))
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
    }
}
