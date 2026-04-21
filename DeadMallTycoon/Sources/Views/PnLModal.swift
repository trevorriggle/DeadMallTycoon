import SwiftUI

// Full monthly P&L breakdown. Opens when the Cash cell in the top strip is tapped.
// Content lifted from the Phase 1-5 MallView.leftPanel (Monthly P&L, State,
// Score Sources) plus the old OpsTabsView.revenueTab (per-tenant revenue,
// other income). Score + sparkline live here — they were removed from the
// top strip per the Phase A UI overhaul to keep the strip focused on the
// two north-star numbers (Cash and Month).
struct PnLModal: View {
    @Bindable var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                scoreAndMonth
                monthlyPnL
                state
                scoreSources
                revenueByTenant
                otherIncome
            }
            .padding(20)
        }
        .background(Color(hex: "#14141a"))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("MONTHLY P&L")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(hex: "#b8e8f8"))
            Spacer()
            Button("Close") { dismiss() }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#6a6a78"))
        }
    }

    // MARK: - Score + months survived hero row

    private var scoreAndMonth: some View {
        let monthsSurvived = (vm.state.year - GameConstants.startingYear) * 12
                           + vm.state.month + 1
        return HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color(hex: "#6a6a78"))
                Text(vm.state.score.formatted())
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: "#7fd3f0"))
                Text("LAST MONTH  \(vm.state.lastMonthlyScore >= 0 ? "+" : "")\(vm.state.lastMonthlyScore)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(hex: "#6a6a78"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("MONTH")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color(hex: "#6a6a78"))
                Text("\(monthsSurvived)")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: "#ff4dbd"))
                Text("\(GameConstants.months[vm.state.month]) \(String(vm.state.year))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(hex: "#6a6a78"))
            }
            Spacer(minLength: 0)
            ScoreSparklineView(history: vm.state.scoreHistory)
                .frame(width: 120, height: 50)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#0a0a0e"))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: "#3a3a48")))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Monthly P&L

    private var monthlyPnL: some View {
        let r = Economy.rent(vm.state)
        let ad = Economy.adRevenue(vm.state)
        let pr = Economy.promoRevenue(vm.state)
        let ops = Economy.operatingCost(vm.state)
        let st = Economy.staffCost(vm.state)
        let pc = Economy.promoCost(vm.state)
        let fines = Economy.hazardFines(vm.state)
        let net = r + ad + pr - ops - st - pc - fines
        let promoNet = pr - pc

        return sectionPanel(title: "Monthly P&L") {
            statRow("Rent",      fmtK(r),                                  color: .green)
            statRow("Ad",        ad > 0 ? "+\(fmtK(ad))" : "$0",            color: .green)
            statRow("Operating", "-\(fmtK(ops))",                          color: .red)
            statRow("Staff",     st > 0 ? "-\(fmtK(st))" : "$0",            color: .red)
            statRow("Promos",    promoNet >= 0 ? "+\(fmtK(promoNet))" : "-\(fmtK(-promoNet))",
                    color: promoNet >= 0 ? .green : .red)
            statRow("Fines",     fines > 0 ? "-\(fmtK(fines))" : "$0",      color: .red)
            Divider().background(Color(hex: "#3a3a48")).padding(.vertical, 2)
            statRow("NET", (net >= 0 ? "+" : "-") + fmtK(abs(net)),
                    color: net >= 0 ? .green : .red, bold: true)
        }
    }

    // MARK: - State

    private var state: some View {
        let open = Mall.openStores(vm.state)
        let occ = open.filter { $0.tier != .vacant }.count
        return sectionPanel(title: "State") {
            statRow("Occupancy", "\(occ)/\(open.count)", color: .primary)
            statRow("Mood",      Mall.state(vm.state).rawValue.capitalized, color: .primary)
        }
    }

    // MARK: - Score sources

    private var scoreSources: some View {
        let open = Mall.openStores(vm.state)
        let emptyCount = open.filter { $0.tier == .vacant }.count
        let sealedBonus = (Mall.isWingClosed(.north, in: vm.state) ? 5 : 0)
                        + (Mall.isWingClosed(.south, in: vm.state) ? 5 : 0)
        let life = Scoring.lifeMultiplier(vm.state)

        return sectionPanel(title: "Score Sources") {
            statRow("Empty stores", "\(emptyCount)", color: .yellow)
            statRow("Sealed wings", "\(sealedBonus)", color: .yellow)
            statRow("Life factor",  String(format: "%.2f×", life),
                    color: life == 0 ? .red : life < 0.5 ? .yellow : .green)
            statRow("This month",
                    "\(vm.state.lastMonthlyScore >= 0 ? "+" : "")\(vm.state.lastMonthlyScore)",
                    color: .yellow)
        }
    }

    // MARK: - Revenue by tenant

    private var revenueByTenant: some View {
        let sorted = vm.state.stores
            .filter { $0.tier != .vacant && !Mall.isWingClosed($0.wing, in: vm.state) }
            .sorted { $0.rent > $1.rent }

        return sectionPanel(title: "Revenue by Tenant") {
            if sorted.isEmpty {
                Text("No active tenants.")
                    .font(.system(size: 13, design: .monospaced)).italic()
                    .foregroundStyle(Color(hex: "#555"))
            } else {
                ForEach(sorted) { s in
                    HStack {
                        Text(s.name).foregroundStyle(Color(hex: "#d8d8e0"))
                        Spacer()
                        Text("$\(s.rent.formatted())").foregroundStyle(.green)
                    }
                    .font(.system(size: 14, design: .monospaced))
                }
            }
        }
    }

    // MARK: - Other income

    private var otherIncome: some View {
        let profitablePromos = vm.state.activePromos.filter { $0.monthlyCost < 0 }
        let hasAny = !vm.state.activeAdDeals.isEmpty || !profitablePromos.isEmpty

        return sectionPanel(title: "Other Income") {
            if !hasAny {
                Text("No ad deals or profitable promos active.")
                    .font(.system(size: 13, design: .monospaced)).italic()
                    .foregroundStyle(Color(hex: "#555"))
            } else {
                ForEach(vm.state.activeAdDeals) { d in
                    HStack {
                        Text(d.name).foregroundStyle(Color(hex: "#d8d8e0"))
                        Spacer()
                        Text("+$\(d.income.formatted())").foregroundStyle(.green)
                    }
                    .font(.system(size: 14, design: .monospaced))
                }
                ForEach(profitablePromos) { p in
                    HStack {
                        Text(p.name).foregroundStyle(Color(hex: "#d8d8e0"))
                        Spacer()
                        Text("+$\((-p.monthlyCost).formatted())").foregroundStyle(.green)
                    }
                    .font(.system(size: 14, design: .monospaced))
                }
            }
        }
    }

    // MARK: - Shared helpers

    @ViewBuilder
    private func sectionPanel<Content: View>(title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#7fd3f0"))
                .padding(.bottom, 4)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#0a0a0e"))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: "#3a3a48")))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func statRow(_ label: String, _ value: String, color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(Color(hex: "#6a6a78"))
            Spacer()
            Text(value)
                .foregroundStyle(color)
                .monospacedDigit()
                .fontWeight(bold ? .black : .regular)
        }
        .font(.system(size: 14, design: .monospaced))
    }

    private func fmtK(_ n: Int) -> String {
        let v = Double(abs(n)) / 1000
        return "$" + String(format: "%.1fk", v)
    }
}
