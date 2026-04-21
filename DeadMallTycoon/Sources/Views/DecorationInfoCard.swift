import SwiftUI

// Floating card that appears when a decoration is tapped.
// Content lifted from the Phase 1-5 MallView.SelectedDetailView.decorationDetail.
// Phase B positions the card at bottom-center of the scene; Phase C will pin
// it near the tapped decoration via scene→SwiftUI coordinate conversion.
struct DecorationInfoCard: View {
    @Bindable var vm: GameViewModel
    let decorationId: Int

    var body: some View {
        if let dec = vm.state.decorations.first(where: { $0.id == decorationId }) {
            card(dec)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder private func card(_ d: Decoration) -> some View {
        let type = DecorationTypes.type(d.kind)
        let mult = d.condition >= 4 ? type.ruinMult : type.baseMult * (1 + Double(d.condition) * 0.2)

        VStack(alignment: .leading, spacing: 8) {
            header(typeName: type.name, conditionLabel: conditionLabel(d))

            Text(type.description)
                .font(.system(size: 13, design: .serif)).italic()
                .foregroundStyle(Color(hex: "#d8d8e0"))

            statLine(label: "Multiplier",
                     value: "+\(Int((mult * 100).rounded()))%",
                     color: .yellow)

            if d.hazard {
                statLine(label: "Monthly fine",
                         value: "-$\(500 + d.condition * 200)",
                         color: Color(hex: "#ff4dbd"))
            }

            // Actions
            Button("Repair ($\(type.repair))") { vm.repairDecoration(d.id) }
                .buttonStyle(.bordered)
                .disabled(vm.state.cash < type.repair)
                .frame(maxWidth: .infinity)
            Button("Remove (free)") { vm.removeDecoration(d.id) }
                .buttonStyle(.bordered)
                .tint(.red)
                .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(maxWidth: 360)
        .background(Color(hex: "#14141a"))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: "#3a3a48"), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.6), radius: 12, y: 4)
    }

    private func header(typeName: String, conditionLabel: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(typeName.uppercased())
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: "#7fd3f0"))
                Text(conditionLabel)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(hex: "#6a6a78"))
            }
            Spacer(minLength: 4)
            Button(action: { vm.clearSelection() }) {
                Text("×")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: "#6a6a78"))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
    }

    private func conditionLabel(_ d: Decoration) -> String {
        let condition = (Condition(rawValue: d.condition) ?? .pristine).name
        return d.hazard ? "\(condition) · HAZARD" : condition
    }

    private func statLine(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(Color(hex: "#6a6a78"))
            Spacer()
            Text(value).foregroundStyle(color).monospacedDigit()
        }
        .font(.system(size: 14, design: .monospaced))
    }
}
