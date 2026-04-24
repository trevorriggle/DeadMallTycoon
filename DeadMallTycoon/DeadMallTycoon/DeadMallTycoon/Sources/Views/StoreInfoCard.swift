import SwiftUI

// Floating card that appears when a storefront is tapped.
// Content lifted from the Phase 1-5 MallView.SelectedDetailView.storeDetail.
// Phase B positions the card at bottom-center of the scene; Phase C will pin
// it near the tapped storefront via scene→SwiftUI coordinate conversion.
struct StoreInfoCard: View {
    @Bindable var vm: GameViewModel
    let storeId: Int

    var body: some View {
        if let store = vm.state.stores.first(where: { $0.id == storeId }) {
            card(store)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder private func card(_ s: Store) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(s)
            if s.tier == .vacant {
                vacantBody(s)
            } else {
                activeBody(s)
            }
        }
        .padding(14)
        .frame(maxWidth: 360)
        .background(Color(hex: "#14141a"))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: "#3a3a48"), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.6), radius: 12, y: 4)
    }

    // MARK: - Header with close affordance

    private func header(_ s: Store) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText(s))
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(titleColor(s))
                Text(subtitleText(s))
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

    private func titleText(_ s: Store) -> String {
        if s.tier == .vacant {
            if s.monthsVacant >= 18 { return "LONG ABANDONED" }
            if s.monthsVacant >= 6  { return "BOARDED UP" }
            return "EMPTY STOREFRONT"
        }
        return s.name.uppercased()
    }

    private func titleColor(_ s: Store) -> Color {
        s.tier == .vacant ? Color(hex: "#6a6a78") : Color(hex: "#7fd3f0")
    }

    private func subtitleText(_ s: Store) -> String {
        if s.tier == .vacant {
            return "\(s.wing.rawValue) wing · \(s.monthsVacant)mo empty"
        }
        return "\(s.tier.rawValue) · \(s.wing.rawValue) wing"
    }

    // MARK: - Vacant body: explain the score contribution

    private func vacantBody(_ s: Store) -> some View {
        Text("This empty space is generating score every month.")
            .font(.system(size: 14, design: .default))
            .italic()
            .foregroundStyle(Color(hex: "#d8d8e0"))
    }

    // MARK: - Active tenant body: rent, rent adjust, promo, evict

    private func activeBody(_ s: Store) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            statLine(label: "Rent", value: "$\(s.rent.formatted())/mo", color: .yellow)
            if s.closing {
                statLine(label: "Status", value: "CLOSING", color: Color(hex: "#ff2f4a"))
            } else if s.leaving {
                statLine(label: "Status", value: "Lease ending", color: Color(hex: "#ff4dbd"))
            } else if s.hardship >= 2 {
                statLine(label: "Status", value: "Struggling", color: Color(hex: "#ff4dbd"))
            }
            statLine(label: "Lease", value: "\(s.lease) months", color: Color(hex: "#d8d8e0"))

            // Rent adjustment row
            HStack(spacing: 6) {
                Button("−") { vm.adjustRent(storeId: s.id, delta: -0.1) }
                    .buttonStyle(.bordered).disabled(s.rentMultiplier <= 0.5)
                Text(String(format: "Rent ×%.1f", s.rentMultiplier))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow).frame(maxWidth: .infinity)
                Button("+") { vm.adjustRent(storeId: s.id, delta: 0.1) }
                    .buttonStyle(.bordered).disabled(s.rentMultiplier >= 2.0)
            }
            .padding(.top, 2)

            // Store-local promo
            Button(s.promotionActive ? "Promo Active" : "Run Store Promo ($500)") {
                vm.runStorePromo(s.id)
            }
            .buttonStyle(.bordered)
            .disabled(vm.state.cash < 500 || s.promotionActive)
            .frame(maxWidth: .infinity)

            // Force evict
            Button("Force Evict (−20% score)") { vm.evictStore(s.id) }
                .buttonStyle(.bordered)
                .tint(.red)
                .frame(maxWidth: .infinity)
        }
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
