import SwiftUI

// Full monthly P&L breakdown. Opens when the Cash cell in the top strip is tapped.
// Phase A stub — Phase B lifts the Monthly P&L, State, Score Sources, and Revenue
// sections from old MallView.leftPanel + OpsTabsView.revenueTab, plus the relocated
// ScoreSparklineView, into this modal.
struct PnLModal: View {
    @Bindable var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MONTHLY P&L")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color(hex: "#f4e4b0"))
                Spacer()
                Button("Close") { dismiss() }
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#888780"))
            }
            Text("Revenue, operating costs, score sources, sparkline — Phase B")
                .font(.system(size: 15, design: .serif))
                .italic()
                .foregroundStyle(Color(hex: "#888780"))
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(hex: "#1a1917"))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
