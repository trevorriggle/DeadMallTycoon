import SwiftUI

// Bottom-drawer management sheet. Seven tabs:
// Acquire · Tenants · Promos · Staff · Wings · Ads · History.
// v9 Prompt 3 — Build tab renamed Acquire and moved to the first slot (more
// prominent) per the spec: "the option to add new decorations needs to be
// much more obvious in the UI." Also lists the full 26 placeable Artifact
// types, not just the 6 legacy decorations.
// v9 Prompt 9 Phase B — added History tab (seventh). Renders the run's
// LedgerEntry list via the shared LedgerView — same view used in the
// end-screen. Tab is last because it's reference, not action: the other
// six are verbs the player performs, History is the mall's narrative log.
struct ManageDrawer: View {
    @Bindable var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tab: ManageTab = .acquire

    // v9 Prompt 9 Phase C — detent binding so History-tab taps can snap
    // the drawer down to .medium, exposing the scene behind where the
    // focus pulse runs. Binding is local to ManageDrawer (no parent
    // coordination needed); at .medium, SwiftUI leaves it alone.
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider().background(Color(hex: "#3a3a48"))
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    switch tab {
                    case .acquire: acquireTab
                    case .tenants: tenantsTab
                    case .promos:  promosTab
                    case .staff:   staffTab
                    case .wings:   wingsTab
                    case .ads:     adsTab
                    case .history: historyTab
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .background(Color(hex: "#14141a"))
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        // v9 patch — decision-sheet pause. The drawer is a decision surface
        // (Acquire, Tenants, Wings, etc. are all player choices), so time
        // stops while it's open. Ownership hands off if something else
        // already owns the pause (tenant offer, tutorial coachmark).
        .onAppear    { vm.pauseForDecisionSheet() }
        .onDisappear { vm.resumeFromDecisionSheet() }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            Text("MANAGE")
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

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ManageTab.allCases, id: \.self) { t in
                    Button(action: { tab = t }) {
                        Text(t.title.uppercased())
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundStyle(t == tab ? Color(hex: "#7fd3f0") : Color(hex: "#6a6a78"))
                            .background(t == tab ? Color(hex: "#1a1a22") : Color.clear)
                            .overlay(
                                Rectangle().frame(height: 2)
                                    .foregroundStyle(t == tab ? Color(hex: "#7fd3f0") : Color.clear),
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
                            Text("~\(baseRate)% success").foregroundStyle(Color(hex: "#6a6a78"))
                        }
                        Text("\(t.tier.rawValue) · $\(t.rent.formatted())/mo · \(t.lease)mo lease")
                            .font(.system(size: 12)).foregroundStyle(Color(hex: "#6a6a78"))
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
                Text(s.name).font(.system(size: 16, weight: .bold)).foregroundStyle(Color(hex: "#7fd3f0"))
                Spacer()
                Text(status).font(.system(size: 12)).foregroundStyle(statusColor)
            }
            Text("\(s.tier.rawValue) · \(s.wing.rawValue) · $\(s.rent.formatted())/mo @ \(Int((s.rentMultiplier * 100).rounded()))% · \(s.lease)mo")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(hex: "#6a6a78"))
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
        .background(Color(hex: "#1a1a22"))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#3a3a48")))
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
                            .foregroundStyle(Color(hex: "#7fd3f0"))
                        Text("\(p.remaining) months remaining")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color(hex: "#6a6a78"))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#1a1a22"))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#3a3a48")))
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
                                .foregroundStyle(Color(hex: "#6a6a78"))
                        }
                        Text(p.description).font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#6a6a78"))
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
                        Text(type.description).font(.system(size: 12)).foregroundStyle(Color(hex: "#6a6a78"))
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
                .foregroundStyle(Color(hex: "#7fd3f0"))
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
                            .foregroundStyle(Color(hex: "#6a6a78"))
                    }
                }
            }
        }
    }

    // MARK: - History (v9 Prompt 9 Phase B + C)

    // The ledger. Year-grouped, scrollable (drawer's top-level ScrollView
    // handles scrolling). Placeholder "[ledger pending: …]" strings render
    // as-is until the authoring pass lands — that's expected; the
    // structure is legible even without the prose.
    //
    // v9 Prompt 9 Phase C — tapping a row routes through
    // vm.focusLedgerEntry, which either sets state.pendingFocusArtifactId
    // (MallScene then runs a 2-second ring pulse on the referenced node)
    // or pushes a "no longer exists" toast. Every tap also snaps the
    // drawer detent to .medium so the scene behind is visible; at the
    // large detent the drawer covers the pulse entirely. Non-tappable
    // cases (envTransition, offerDestruction, artifactDestroyed) skip
    // the tap wiring at the LedgerEntryRow level.
    private var historyTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("The Ledger")
            subtle("Every closure, every decay, every era — as the mall remembers it.")
            LedgerView(
                entries: vm.state.ledger,
                emptyStateText: "No entries yet. Nothing has happened worth remembering.",
                onEntryTap: { entry in
                    vm.focusLedgerEntry(entry)
                    withAnimation { detent = .medium }
                }
            )
        }
    }

    // MARK: - Acquire (v9 Prompt 3)

    // v8: buildTab — six-kind decoration picker.
    // v9 Prompt 3 — full Artifact roster.
    // v9 Prompt 3 followup — list body extracted to ArtifactAcquirePanel so
    // both this tab and the standalone HUD Acquire sheet use the same UI.
    // Tapping a row starts placement and closes the drawer so the player
    // can tap the corridor.
    private var acquireTab: some View {
        ArtifactAcquirePanel(vm: vm) { type in
            vm.beginPlacement(type)
            dismiss()
        }
    }

    // MARK: - Shared helpers

    private func sectionHeader(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Color(hex: "#7fd3f0"))
            .padding(.top, 2)
    }

    private func subtle(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 12, design: .monospaced)).italic()
            .foregroundStyle(Color(hex: "#6a6a78"))
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
                .foregroundStyle(active ? Color(hex: "#9FE1CB") : Color(hex: "#e8e8f0"))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(active ? Color(hex: "#2a4a3a") : Color(hex: "#1a1a22"))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(active ? Color(hex: "#0f6e56") : Color(hex: "#3a3a48")))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }
}

enum ManageTab: String, CaseIterable, Hashable {
    // v8/Prompt 1-2: tenants, promos, staff, wings, ads, build.
    // v9 Prompt 3 — `build` renamed `acquire` and promoted to the first slot
    // so artifact placement is the most obvious entry point in the drawer.
    // v9 Prompt 9 Phase B — `history` appended as the seventh tab (the
    // mall's narrative log; reference, not action).
    case acquire, tenants, promos, staff, wings, ads, history
    var title: String {
        switch self {
        case .acquire: return "Acquire"
        case .tenants: return "Tenants"
        case .promos:  return "Promos"
        case .staff:   return "Staff"
        case .wings:   return "Wings"
        case .ads:     return "Ads"
        case .history: return "History"
        }
    }
}
