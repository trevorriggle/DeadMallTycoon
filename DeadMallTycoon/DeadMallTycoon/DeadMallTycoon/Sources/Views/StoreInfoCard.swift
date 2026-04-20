import SwiftUI

// Floating card that appears when a storefront is tapped.
// Phase A stub — fixed bottom-center position + "TK" body. Phase B lifts the real
// detail view from old MallView.SelectedDetailView and positions the card near the
// tapped storefront using scene→screen coord conversion.
struct StoreInfoCard: View {
    @Bindable var vm: GameViewModel
    let storeId: Int

    var body: some View {
        let store = vm.state.stores.first(where: { $0.id == storeId })
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text((store?.tier == .vacant ? "VACANT" : store?.name ?? "STORE").uppercased())
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
            Text("Store info · Phase B")
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
