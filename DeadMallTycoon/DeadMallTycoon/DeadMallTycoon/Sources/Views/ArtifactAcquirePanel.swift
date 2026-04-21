import SwiftUI

// v9 Prompt 3 followup — shared content for the Acquire picker. Used by both
// the Acquire tab inside ManageDrawer AND the standalone ArtifactAcquireSheet
// launched from the top-level HUD Acquire button. Single source of truth: if
// the list layout changes, it changes in one place.
//
// The panel has no chrome of its own (no header, no padding around the list)
// — parent views wrap it with whatever sheet / drawer surround they need.
// Parents pass `onSelect` which receives the chosen ArtifactType. Typical
// parent action: vm.beginPlacement(type) + dismiss the sheet so the player
// can tap the corridor.
struct ArtifactAcquirePanel: View {
    @Bindable var vm: GameViewModel
    let onSelect: (ArtifactType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("Acquire Artifacts")
            subtitle("Aesthetic multipliers. Decay with time — a ruined fountain scores more than a working one.")
            if vm.state.placingArtifactType != nil {
                placementBanner
            }
            ForEach(ArtifactCatalog.placeableTypes, id: \.self) { type in
                let info = ArtifactCatalog.info(type)
                actionRow(
                    disabled: vm.state.cash < info.cost,
                    action: { onSelect(type) }
                ) {
                    HStack {
                        Text("\(info.name) · $\(info.cost.formatted())")
                        Spacer()
                        Text("(+\(Int((info.baseMult * 100).rounded()))% mult, ruin +\(Int((info.ruinMult * 100).rounded()))%)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#6a6a78"))
                    }
                }
            }
        }
    }

    // MARK: - Stylings (intentionally self-contained so this view doesn't
    // depend on private helpers from ManageDrawer)

    private func header(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Color(hex: "#7fd3f0"))
            .padding(.top, 2)
    }

    private func subtitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced)).italic()
            .foregroundStyle(Color(hex: "#6a6a78"))
            .padding(.bottom, 2)
    }

    private var placementBanner: some View {
        Text("Placement mode active. Close this sheet and tap the corridor.")
            .font(.system(size: 13, design: .monospaced)).italic()
            .foregroundStyle(Color(hex: "#7fd3f0"))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#2a2a34"))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#7fd3f0")))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func actionRow<Label: View>(disabled: Bool,
                                        action: @escaping () -> Void,
                                        @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(Color(hex: "#e8e8f0"))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#1a1a22"))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(hex: "#3a3a48")))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
