import SwiftUI

// Floating card that appears when a decoration is tapped.
// Phase A stub — fixed position + "TK" body. Phase B lifts real detail view and
// positions near the tapped decoration via scene→screen coord conversion.
struct DecorationInfoCard: View {
    @Bindable var vm: GameViewModel
    let decorationId: Int

    var body: some View {
        let dec = vm.state.decorations.first(where: { $0.id == decorationId })
        let typeName = dec.map { DecorationTypes.type($0.kind).name } ?? "DECORATION"
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(typeName.uppercased())
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Color(hex: "#FAC775"))
                Spacer()
                Button(action: { vm.clearSelection() }) {
                    Text("×")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: "#888780"))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
            Text("Decoration info · Phase B")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(Color(hex: "#888780"))
        }
        .padding(12)
        .frame(maxWidth: 320)
        .background(Color(hex: "#1a1917"))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: "#5a4a3a"), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.6), radius: 10, y: 4)
    }
}
