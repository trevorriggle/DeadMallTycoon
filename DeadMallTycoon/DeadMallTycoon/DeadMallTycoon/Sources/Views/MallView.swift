import SwiftUI

// "Mall" tab — the living scene plus three sidebars (P&L, status + watch list, selected + thoughts log).
// Layout mirrors v8's sidebar grid-template-columns: 220px 1fr 260px.
struct MallView: View {
    @Bindable var vm: GameViewModel

    var body: some View {
        VStack(spacing: 8) {
            sceneContainer
                .frame(height: 520)
            HStack(alignment: .top, spacing: 10) {
                leftPanel.frame(width: 280)
                centerPanel
                rightPanel.frame(width: 320)
            }
        }
    }

    private var sceneContainer: some View {
        ZStack {
            MallSceneView(vm: vm)
                .background(Color(hex: "#0a0908"))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: "#3a3935")))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Placement mode banner
            if let kind = vm.state.placingDecoration {
                VStack {
                    Button(action: { vm.cancelPlacement() }) {
                        Text("Placing \(DecorationTypes.type(kind).name) · Click in corridor · Tap to cancel")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Color(hex: "#FAC775").opacity(0.95))
                            .foregroundStyle(Color(hex: "#2a1a0a"))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Left panel: P&L + state + score sources

    private var leftPanel: some View {
        let r = Economy.rent(vm.state)
        let ad = Economy.adRevenue(vm.state)
        let pr = Economy.promoRevenue(vm.state)
        let ops = Economy.operatingCost(vm.state)
        let st = Economy.staffCost(vm.state)
        let pc = Economy.promoCost(vm.state)
        let fines = Economy.hazardFines(vm.state)
        let net = r + ad + pr - ops - st - pc - fines

        return panel {
            sectionHeader("Monthly P&L")
            statRow("Rent",      fmtK(r),       color: .green)
            statRow("Ad",        ad > 0 ? "+\(fmtK(ad))" : "$0", color: .green)
            statRow("Operating", "-\(fmtK(ops))", color: .red)
            statRow("Staff",     st > 0 ? "-\(fmtK(st))" : "$0", color: .red)
            let promoNet = pr - pc
            statRow("Promos",    promoNet >= 0 ? "+\(fmtK(promoNet))" : "-\(fmtK(-promoNet))",
                    color: promoNet >= 0 ? .green : .red)
            statRow("Fines",     fines > 0 ? "-\(fmtK(fines))" : "$0", color: .red)
            Divider().background(Color(hex: "#5a4a3a"))
            statRow("NET", (net >= 0 ? "+" : "-") + fmtK(net),
                    color: net >= 0 ? .green : .red)

            sectionHeader("State").padding(.top, 10)
            let open = Mall.openStores(vm.state)
            let occ = open.filter { $0.tier != .vacant }.count
            statRow("Occupancy", "\(occ)/\(open.count)", color: .primary)
            statRow("Visitors",  "—", color: .primary)
            statRow("Mood", Mall.state(vm.state).rawValue, color: .primary)

            sectionHeader("Score Sources").padding(.top, 10)
            let emptyCount = open.filter { $0.tier == .vacant }.count
            let sealedBonus = (Mall.isWingClosed(.north, in: vm.state) ? 5 : 0)
                            + (Mall.isWingClosed(.south, in: vm.state) ? 5 : 0)
            statRow("Empty stores", "\(emptyCount)", color: .yellow)
            statRow("Sealed wings", "\(sealedBonus)", color: .yellow)
            let life = Scoring.lifeMultiplier(vm.state)
            statRow("Life factor", String(format: "%.2f×", life),
                    color: life == 0 ? .red : life < 0.5 ? .yellow : .green)
            statRow("This month", "\(vm.state.lastMonthlyScore >= 0 ? "+" : "")\(vm.state.lastMonthlyScore)",
                    color: .yellow)
        }
    }

    // MARK: - Center panel: status + watch list

    private var centerPanel: some View {
        panel {
            sectionHeader("Status")
            Text(Mall.moodText(vm.state))
                .font(.system(size: 15, design: .serif))
                .italic()
                .foregroundStyle(Color(hex: "#c4b4a0"))
                .padding(.bottom, 6)

            sectionHeader("Watch List").padding(.top, 8)
            if vm.state.warnings.isEmpty {
                Text("Nothing urgent. Enjoy it while it lasts.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color(hex: "#555"))
                    .italic()
            } else {
                ForEach(Array(Warnings.sorted(vm.state).prefix(6))) { w in
                    WarningRow(warning: w)
                }
            }
        }
    }

    // MARK: - Right panel: selected + thoughts log

    private var rightPanel: some View {
        panel {
            sectionHeader("Selected")
            SelectedDetailView(vm: vm)

            sectionHeader("Thoughts Overheard").padding(.top, 10)
            if vm.state.thoughtsLog.isEmpty {
                Text("Tap visitors to overhear them.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color(hex: "#555"))
                    .italic()
            } else {
                ForEach(vm.state.thoughtsLog) { t in
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(t.visitorName) · \(t.personality)".uppercased())
                            .font(.system(size: 12, design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(Color(hex: "#888780"))
                        Text(t.text)
                            .font(.system(size: 14, design: .serif))
                            .italic()
                            .foregroundStyle(Color(hex: "#a89484"))
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#1a1410"))
                    .overlay(Rectangle().frame(width: 2).foregroundStyle(Color(hex: "#5a4a3a")), alignment: .leading)
                }
            }
        }
    }

    // MARK: Helpers

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#1a1917"))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: "#3a3935")))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func sectionHeader(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 14, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(Color(hex: "#888780"))
    }

    private func statRow(_ label: String, _ value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(Color(hex: "#888780"))
            Spacer()
            Text(value).foregroundStyle(color).monospacedDigit()
        }
        .font(.system(size: 15, design: .monospaced))
    }

    private func fmtK(_ n: Int) -> String {
        let v = Double(abs(n)) / 1000
        return "$\(String(format: "%.1f", v))k"
    }
}

struct WarningRow: View {
    let warning: Warning
    var body: some View {
        Text(warning.text)
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(Color(hex: "#c4b4a0"))
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(warning.severity == .danger ? Color(hex: "#2a1515") : Color(hex: "#1a1410"))
            .overlay(Rectangle().frame(width: 3).foregroundStyle(borderColor), alignment: .leading)
    }
    private var borderColor: Color {
        switch warning.severity {
        case .watch:  return Color(hex: "#5a9490")
        case .warn:   return Color(hex: "#EF9F27")
        case .danger: return Color(hex: "#e24b4a")
        }
    }
}

// Detail card for whatever is selected: visitor / store / decoration / nothing
struct SelectedDetailView: View {
    @Bindable var vm: GameViewModel

    var body: some View {
        if let id = vm.state.selectedStoreId,
           let store = vm.state.stores.first(where: { $0.id == id }) {
            storeDetail(store)
        } else if let id = vm.state.selectedDecorationId,
                  let dec = vm.state.decorations.first(where: { $0.id == id }) {
            decorationDetail(dec)
        } else if vm.state.selectedVisitorId != nil {
            visitorDetail()
        } else {
            Text("Tap a visitor, store, or decoration.")
                .font(.system(size: 14, design: .monospaced))
                .italic()
                .foregroundStyle(Color(hex: "#888780"))
        }
    }

    private func storeDetail(_ s: Store) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if s.tier == .vacant {
                let label = s.monthsVacant >= 18 ? "Long abandoned"
                          : s.monthsVacant >= 6  ? "Boarded up"
                          : "Empty storefront"
                Text(label).font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: "#888780"))
                Text("\(s.wing.rawValue) wing · \(s.monthsVacant)mo empty")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(hex: "#888780"))
                Text("This empty space is generating score each month.")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundStyle(Color(hex: "#c4b4a0"))
            } else {
                Text(s.name).font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: "#FAC775"))
                Text("\(s.tier.rawValue) · \(s.wing.rawValue)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(hex: "#888780"))
                HStack {
                    Text("Rent").foregroundStyle(Color(hex: "#888780"))
                    Spacer()
                    Text("$\(s.rent.formatted())/mo").foregroundStyle(.yellow)
                }.font(.system(size: 15, design: .monospaced))
                HStack(spacing: 4) {
                    Button("−") { vm.adjustRent(storeId: s.id, delta: -0.1) }
                        .buttonStyle(.bordered).disabled(s.rentMultiplier <= 0.5)
                    Text(String(format: "Rent ×%.1f", s.rentMultiplier))
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(.yellow).frame(maxWidth: .infinity)
                    Button("+") { vm.adjustRent(storeId: s.id, delta: 0.1) }
                        .buttonStyle(.bordered).disabled(s.rentMultiplier >= 2.0)
                }
                Button(s.promotionActive ? "Promo Active" : "Store Promo ($500)") {
                    vm.runStorePromo(s.id)
                }
                .buttonStyle(.bordered)
                .disabled(vm.state.cash < 500 || s.promotionActive)
                Button("Force Evict (−20% score)") { vm.evictStore(s.id) }
                    .buttonStyle(.bordered)
                    .tint(.red)
            }
        }
    }

    private func decorationDetail(_ d: Decoration) -> some View {
        let type = DecorationTypes.type(d.kind)
        let mult = d.condition >= 4 ? type.ruinMult : type.baseMult * (1 + Double(d.condition) * 0.2)
        return VStack(alignment: .leading, spacing: 6) {
            Text(type.name).font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(hex: "#FAC775"))
            Text("\((Condition(rawValue: d.condition) ?? .pristine).name)\(d.hazard ? " · HAZARD" : "")")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color(hex: "#888780"))
            Text(type.description)
                .font(.system(size: 14, design: .serif)).italic()
                .foregroundStyle(Color(hex: "#c4b4a0"))
            HStack {
                Text("Multiplier").foregroundStyle(Color(hex: "#888780"))
                Spacer()
                Text("+\(Int((mult * 100).rounded()))%").foregroundStyle(.yellow)
            }.font(.system(size: 15, design: .monospaced))
            if d.hazard {
                HStack {
                    Text("Monthly fine").foregroundStyle(Color(hex: "#888780"))
                    Spacer()
                    Text("-$\(500 + d.condition * 200)").foregroundStyle(.red)
                }.font(.system(size: 15, design: .monospaced))
            }
            Button("Repair ($\(type.repair))") { vm.repairDecoration(d.id) }
                .buttonStyle(.bordered)
                .disabled(vm.state.cash < type.repair)
            Button("Remove (free)") { vm.removeDecoration(d.id) }
                .buttonStyle(.bordered)
        }
    }

    private func visitorDetail() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Visitor").font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(hex: "#FAC775"))
            if !vm.state.selectedVisitorThought.isEmpty {
                Text("OVERHEARD")
                    .font(.system(size: 12, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: "#888780"))
                Text(vm.state.selectedVisitorThought)
                    .font(.system(size: 15, design: .serif))
                    .italic()
                    .foregroundStyle(Color(hex: "#e8dcc8"))
                    .padding(8)
                    .background(Color(hex: "#1a1410"))
                    .overlay(Rectangle().frame(width: 3).foregroundStyle(Color(hex: "#c4919a")), alignment: .leading)
            }
        }
    }
}
