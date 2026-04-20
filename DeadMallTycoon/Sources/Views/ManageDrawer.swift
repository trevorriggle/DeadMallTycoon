import SwiftUI

// Bottom-drawer management sheet. Six tabs: Tenants · Promos · Staff · Wings · Ads · Build.
// Content lifted verbatim from the Phase 1-5 OpsTabsView — one tab per thematic
// section of the old Operations / Tenants / Promotions tabs.
// Revenue sections moved out of the drawer and into the PnLModal (read-only info
// belongs with the rest of the P&L breakdown).
struct ManageDrawer: View {
    @Bindable var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tab: ManageTab = .tenants

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider().background(Color(hex: "#3a3935"))
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    switch tab {
                    case .tenants: tenantsTab
                    case .promos:  promosTab
                    case .staff:   staffTab
                    case .wings:   wingsTab
                    case .ads:     adsTab
                    case .build:   buildTab
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .background(Color(hex: "#1a1917"))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            Text("MANAGE")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(hex: "#f4e4b0"))
            Spacer()
            Button("Close") { dismiss() }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#888780"))
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ManageTab.allCases, id: \.self) { t in
                    Button(action: { tab = t }) {
                        Text(t.title.uppercased())
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundStyle(t == tab ? Color(hex: "#FAC775") : Color(hex: "#888780"))
                            .background(t == tab ? Color(hex: "#2a2520") : Color.clear)
                            .overlay(
                                Rectangle().frame(height: 2)
                                    .foregroundStyle(t == tab ? Color(hex: "#FAC775") : Color.clear),
                                alignment: .bottom
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Tenants

    private var tenantsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Active Tenants")
            subtle("Higher rent = more money but more stress. Force-evict to trade score for empty slots.")
            let active = vm.state.stores.filter { $0.tier != .vacant && !Mall.isWingClosed($0.wing, in: vm.state) }
            if active.isEmpty {
                emptyState("No active tenants. The mall is fully empty.")
            } else {
                ForEach(active) { s in activeTenantRow(s) }
            }

            sectionHeader("Approach Prospective Tenants").padding(.top, 10)
            subtle("Traffic affects success rate. Low traffic = fewer willing tenants.")
            ForEach(Array(Tenants.targetsAll.enumerated()), id: \.offset) { pair in
                let i = pair.offset
                let t = pair.element
                let canApproach = t.requiredStates.contains(Mall.state(vm.state)) && vm.state.cash >= t.approachCost
                let baseRate: Int = {
                    switch Mall.state(vm.state) {
                    case .thriving:   return 80
                    case .fading:     return 65
                    case .struggling: return 50
                    case .dying:      return 35
                    case .dead:       return 20
                    }
                }()
                actionButton(active: false) {
                    _ = vm.approachTenant(i)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(t.name) · $\(t.approachCost)")
                            Spacer()
                            Text("~\(baseRate)% success").foregroundStyle(Color(hex: "#888780"))
                        }
                        Text("\(t.tier.rawValue) · $\(t.rent.formatted())/mo · \(t.lease)mo lease")
                            .font(.system(size: 12)).foregroundStyle(Color(hex: "#888780"))
                    }
                }
                .disabled(!canApproach)
            }
        }
    }

    private func activeTenantRow(_ s: Store) -> some View {
        let status = s.closing ? "CLOSING"
                   : s.leaving ? "Lease ending"
                   : s.hardship >= 2 ? "Struggling" : "OK"
        let statusColor: Color = s.closing ? .red
                               : s.hardship >= 2 ? .yellow : .green
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(s.name).font(.system(size: 16, weight: .bold)).foregroundStyle(Color(hex: "#FAC775"))
                Spacer()
                Text(status).font(.system(size: 12)).foregroundStyle(statusColor)
            }
            Text("\(s.tier.rawValue) · \(s.wing.rawValue) · $\(s.rent.formatted())/mo @ \(Int((s.rentMultiplier * 100).rounded()))% · \(s.lease)mo")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(hex: "#888780"))
            HStack(spacing: 4) {
                Button("−") { vm.adjustRent(storeId: s.id, delta: -0.1) }
                    .buttonStyle(.bordered).disabled(s.rentMultiplier <= 0.5)
                Text(String(format: "%.1f×", s.rentMultiplier))
                    .frame(maxWidth: .infinity)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.yellow)
                Button("+") { vm.adjustRent(storeId: s.id, delta: 0.1) }
                    .buttonStyle(.bordered).disabled(s.rentMultiplier >= 2.0)
                Button("Evict") { vm.evictStore(s.id) }
                    .buttonStyle(.bordered).tint(.red)
            }
        }
        .padding(8)
        .background(Color(hex: "#2a2520"))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#5a4a3a")))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Promos

    private var promosTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Active")
            subtle("Running now. Each runs for a set duration.")
            if vm.state.activePromos.isEmpty {
                emptyState("No active promotions.")
            } else {
                ForEach(vm.state.activePromos) { p in
                    VStack(alignment: .leading) {
                        Text(p.name).font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#FAC775"))
                        Text("\(p.remaining) months remaining")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color(hex: "#888780"))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#2a2520"))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#5a4a3a")))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            sectionHeader("Launch").padding(.top, 10)
            subtle("Every promo trades something for something.")
            ForEach(Promotions.all) { p in
                let active = vm.state.activePromos.contains(where: { $0.id == p.id })
                actionButton(active: active) {
                    vm.launchPromo(p.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(p.name) · $\(p.cost)")
                            Spacer()
                            Text(active ? "ACTIVE" : "\(p.duration)mo")
                                .foregroundStyle(Color(hex: "#888780"))
                        }
                        Text(p.description).font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#888780"))
                    }
                }
                .disabled(active || vm.state.cash < p.cost)
            }
        }
    }

    // MARK: - Staff

    private var staffTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Staff")
            subtle("Monthly retainers. Cut what you don't need — or can't afford.")
            ForEach(["security","janitorial","maintenance","marketing"], id: \.self) { key in
                let type = StaffTypes.all[key]!
                let active = isStaffActive(key)
                actionButton(active: active) {
                    vm.toggleStaff(key)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(type.name) · $\(type.cost.formatted())/mo")
                            Spacer()
                            Text(active ? "ACTIVE" : "off").foregroundStyle(active ? .green : .secondary)
                        }
                        Text(type.description).font(.system(size: 12)).foregroundStyle(Color(hex: "#888780"))
                    }
                }
            }
        }
    }

    private func isStaffActive(_ key: String) -> Bool {
        switch key {
        case "security":    return vm.state.activeStaff.security
        case "janitorial":  return vm.state.activeStaff.janitorial
        case "maintenance": return vm.state.activeStaff.maintenance
        case "marketing":   return vm.state.activeStaff.marketing
        default: return false
        }
    }

    // MARK: - Wings

    private var wingsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Wings")
            subtle("Sealing a wing loses tenants but slashes ops and gives +5 score/mo per sealed wing.")
            ForEach(Wing.allCases, id: \.self) { wing in
                wingControls(wing: wing)
            }
        }
    }

    @ViewBuilder private func wingControls(wing: Wing) -> some View {
        let closed = vm.state.wingsClosed[wing] ?? false
        let down = vm.state.wingsDowngraded[wing] ?? false
        VStack(alignment: .leading, spacing: 4) {
            Text("\(wing.rawValue.uppercased()) Wing")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color(hex: "#FAC775"))
                .padding(.top, 6)
            actionButton(active: down) {
                vm.toggleWingDowngrade(wing)
            } label: {
                Text(down ? "Restore Power" : "Downgrade Lighting/HVAC  (−$1.5k/mo, −10% traffic)")
            }
            .disabled(closed)
            actionButton(active: closed) {
                vm.toggleWingClosed(wing)
            } label: {
                Text(closed ? "Reopen Wing" : "Seal Wing  (−$2.5k/mo ops, tenants lost)")
            }
        }
    }

    // MARK: - Ads

    private var adsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Sponsor Deals")
            subtle("Passive income at an aesthetic cost. More ads = uglier mall = lower score multiplier.")
            ForEach(AdDeals.all) { deal in
                let active = vm.state.activeAdDeals.contains(where: { $0.id == deal.id })
                actionButton(active: active) {
                    vm.toggleAdDeal(deal.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(deal.name) · +$\(deal.income.formatted())/mo")
                            Spacer()
                            Text(active ? "ACTIVE" : "off").foregroundStyle(active ? .green : .secondary)
                        }
                        Text("\(deal.description) (−\(Int(deal.aestheticPenalty * 100))% aesthetic)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#888780"))
                    }
                }
            }
        }
    }

    // MARK: - Build

    private var buildTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Decorations")
            subtle("Aesthetic multipliers. Decay with time — a ruined fountain scores more than a working one.")
            if vm.state.placingDecoration != nil {
                Text("Placement mode active. Tap the corridor in the mall scene.")
                    .font(.system(size: 13, design: .monospaced)).italic()
                    .foregroundStyle(Color(hex: "#FAC775"))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#2a1a0a"))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#FAC775")))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            ForEach(Array(DecorationTypes.all.keys), id: \.self) { kind in
                let t = DecorationTypes.type(kind)
                actionButton(active: false) {
                    vm.beginPlacement(kind)
                    // Close the drawer so the player can tap in the corridor.
                    dismiss()
                } label: {
                    HStack {
                        Text("\(t.name) · $\(t.cost.formatted())")
                        Spacer()
                        Text("(+\(Int((t.baseMult * 100).rounded()))% mult, ruin +\(Int((t.ruinMult * 100).rounded()))%)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#888780"))
                    }
                }
                .disabled(vm.state.cash < t.cost)
            }
        }
    }

    // MARK: - Shared helpers

    private func sectionHeader(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Color(hex: "#FAC775"))
            .padding(.top, 2)
    }

    private func subtle(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 12, design: .monospaced)).italic()
            .foregroundStyle(Color(hex: "#888780"))
            .padding(.bottom, 2)
    }

    private func emptyState(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 13, design: .monospaced)).italic()
            .foregroundStyle(Color(hex: "#555"))
            .padding(.vertical, 4)
    }

    private func actionButton<Label: View>(active: Bool, action: @escaping () -> Void,
                                           @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(active ? Color(hex: "#9FE1CB") : Color(hex: "#e8dcc8"))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(active ? Color(hex: "#2a4a3a") : Color(hex: "#2a2520"))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(active ? Color(hex: "#0f6e56") : Color(hex: "#5a4a3a")))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }
}

enum ManageTab: String, CaseIterable, Hashable {
    case tenants, promos, staff, wings, ads, build
    var title: String {
        switch self {
        case .tenants: return "Tenants"
        case .promos:  return "Promos"
        case .staff:   return "Staff"
        case .wings:   return "Wings"
        case .ads:     return "Ads"
        case .build:   return "Build"
        }
    }
}
