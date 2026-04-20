import SwiftUI

// Operations / Tenants / Promotions / Revenue tabs.
// Visually matches v8's .tab-content panels.
struct OpsTabsView: View {
    @Bindable var vm: GameViewModel
    let tab: Tab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header
                switch tab {
                case .operations: operationsTab
                case .tenants:    tenantsTab
                case .promotions: promotionsTab
                case .revenue:    revenueTab
                default:          EmptyView()
                }
            }
            .padding(16)
        }
        .frame(height: 520)
        .background(Color(hex: "#0a0908"))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: "#3a3935")))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - header

    private var headerText: (title: String, desc: String) {
        switch tab {
        case .operations: return ("Operations", "Wings, staff, infrastructure, decorations. How you physically run the building.")
        case .tenants:    return ("Tenants",    "Rent, leases, recruitment. Empty is good for score — just not all of them.")
        case .promotions: return ("Promotions", "Temporary plays to buy traffic or cash. Every one has a tradeoff.")
        case .revenue:    return ("Revenue",    "Where your money is coming from, month to month.")
        default:          return ("","")
        }
    }

    private var header: some View {
        let t = headerText
        return VStack(alignment: .leading, spacing: 4) {
            Text(t.title.uppercased())
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color(hex: "#FAC775"))
            Text(t.desc)
                .font(.system(size: 15, design: .serif)).italic()
                .foregroundStyle(Color(hex: "#c4b4a0"))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#2a2520"))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(hex: "#5a4a3a")))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    // MARK: - Operations tab

    private var operationsTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Staff").padding(.top, 4)
            subtle("Monthly retainers.")
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
                        Text(type.description).font(.system(size: 13)).foregroundStyle(Color(hex: "#888780"))
                    }
                }
            }

            sectionHeader("Wings").padding(.top, 10)
            subtle("Sealing a wing loses tenants but slashes ops and gives +5 score/mo per sealed wing.")
            ForEach(Wing.allCases, id: \.self) { wing in
                wingControls(wing: wing)
            }

            sectionHeader("Ad Revenue").padding(.top, 10)
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
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#888780"))
                    }
                }
            }

            sectionHeader("Decorations").padding(.top, 10)
            subtle("Aesthetic multipliers. Decay with time — a ruined fountain scores more than a working one. Tap to place.")
            ForEach(Array(DecorationTypes.all.keys), id: \.self) { kind in
                let t = DecorationTypes.type(kind)
                actionButton(active: false) {
                    vm.beginPlacement(kind)
                } label: {
                    HStack {
                        Text("\(t.name) · $\(t.cost.formatted())")
                        Spacer()
                        Text("(+\(Int((t.baseMult * 100).rounded()))% mult, ruin +\(Int((t.ruinMult * 100).rounded()))%)")
                            .foregroundStyle(Color(hex: "#888780"))
                    }
                }
                .disabled(vm.state.cash < t.cost)
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

    @ViewBuilder private func wingControls(wing: Wing) -> some View {
        let closed = vm.state.wingsClosed[wing] ?? false
        let down = vm.state.wingsDowngraded[wing] ?? false
        VStack(alignment: .leading, spacing: 4) {
            Text("\(wing.rawValue.uppercased()) Wing")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
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

    // MARK: - Tenants tab

    private var tenantsTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Active Tenants").padding(.top, 4)
            subtle("Higher rent = more money but more stress. Force-evict to trade score for empty slots.")
            let active = vm.state.stores.filter { $0.tier != .vacant && !Mall.isWingClosed($0.wing, in: vm.state) }
            ForEach(active) { s in activeTenantRow(s) }

            sectionHeader("Approach Prospective Tenants").padding(.top, 10)
            subtle("Traffic affects success rate. Low traffic = fewer willing tenants. Late-game offers get desperate.")
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
                            .font(.system(size: 13)).foregroundStyle(Color(hex: "#888780"))
                    }
                }
                .disabled(!canApproach)
            }
        }
    }

    private func activeTenantRow(_ s: Store) -> some View {
        let status = s.closing ? "CLOSING" : s.leaving ? "Lease ending" : s.hardship >= 2 ? "Struggling" : "OK"
        let statusColor: Color = s.closing ? .red : s.hardship >= 2 ? .yellow : .green
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(s.name).font(.system(size: 17, weight: .bold)).foregroundStyle(Color(hex: "#FAC775"))
                Spacer()
                Text(status).font(.system(size: 13)).foregroundStyle(statusColor)
            }
            Text("\(s.tier.rawValue) · \(s.wing.rawValue) · $\(s.rent.formatted())/mo @ \(Int((s.rentMultiplier * 100).rounded()))% · \(s.lease)mo")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color(hex: "#888780"))
            HStack(spacing: 4) {
                Button("−") { vm.adjustRent(storeId: s.id, delta: -0.1) }
                    .buttonStyle(.bordered).disabled(s.rentMultiplier <= 0.5)
                Text(String(format: "%.1f×", s.rentMultiplier))
                    .frame(maxWidth: .infinity)
                    .font(.system(size: 15, design: .monospaced))
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

    // MARK: - Promotions tab

    private var promotionsTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Promotions & Events").padding(.top, 4)
            subtle("Active campaigns run for a set duration. Most trade score aesthetics for traffic or cash.")
            if !vm.state.activePromos.isEmpty {
                ForEach(vm.state.activePromos) { p in
                    VStack(alignment: .leading) {
                        Text(p.name).font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color(hex: "#FAC775"))
                        Text("\(p.remaining) months remaining")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color(hex: "#888780"))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#2a2520"))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#5a4a3a")))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
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
                        Text(p.description).font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#888780"))
                    }
                }
                .disabled(active || vm.state.cash < p.cost)
            }
        }
    }

    // MARK: - Revenue tab

    private var revenueTab: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Revenue by Tenant").padding(.top, 4)
            let sorted = vm.state.stores
                .filter { $0.tier != .vacant && !Mall.isWingClosed($0.wing, in: vm.state) }
                .sorted { $0.rent > $1.rent }
            if sorted.isEmpty {
                Text("No active tenants.")
                    .font(.system(size: 14, design: .monospaced)).italic()
                    .foregroundStyle(Color(hex: "#555"))
            }
            ForEach(sorted) { s in
                HStack {
                    Text(s.name).foregroundStyle(Color(hex: "#888780"))
                    Spacer()
                    Text("$\(s.rent.formatted())").foregroundStyle(.green)
                }
                .font(.system(size: 15, design: .monospaced))
                .padding(.vertical, 2)
            }

            sectionHeader("Other Income").padding(.top, 10)
            if vm.state.activeAdDeals.isEmpty && vm.state.activePromos.filter({ $0.monthlyCost < 0 }).isEmpty {
                Text("No ad deals or profitable promos active.")
                    .font(.system(size: 14, design: .monospaced)).italic()
                    .foregroundStyle(Color(hex: "#555"))
            }
            ForEach(vm.state.activeAdDeals) { d in
                HStack {
                    Text(d.name).foregroundStyle(Color(hex: "#888780"))
                    Spacer()
                    Text("+$\(d.income.formatted())").foregroundStyle(.green)
                }
                .font(.system(size: 15, design: .monospaced))
            }
            ForEach(vm.state.activePromos.filter { $0.monthlyCost < 0 }) { p in
                HStack {
                    Text(p.name).foregroundStyle(Color(hex: "#888780"))
                    Spacer()
                    Text("+$\((-p.monthlyCost).formatted())").foregroundStyle(.green)
                }
                .font(.system(size: 15, design: .monospaced))
            }
        }
    }

    // MARK: Helpers

    private func sectionHeader(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(Color(hex: "#FAC775"))
            .padding(.top, 2)
    }

    private func subtle(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 13, design: .monospaced)).italic()
            .foregroundStyle(Color(hex: "#888780"))
            .padding(.bottom, 2)
    }

    private func actionButton<Label: View>(active: Bool, action: @escaping () -> Void,
                                           @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .font(.system(size: 14, weight: .bold, design: .monospaced))
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
