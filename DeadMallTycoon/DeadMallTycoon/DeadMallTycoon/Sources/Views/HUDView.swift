import SwiftUI

// Thin edge-anchored top strip per the Phase A UI overhaul.
// Date + "MONTH N" survival counter · Cash (tap → P&L modal) · Threat meter.
// Target height ≈ 40pt exclusive of safe-area padding.
//
// Score, sparkline, speed buttons, and debt-as-separate-cell were removed from
// the top strip on purpose — they live in the P&L modal / bottom-right corner /
// inline debt subscript respectively. The game's north-star numbers in the strip
// are CASH (can you pay next month?) and MONTH (how long have you lasted?).
struct HUDView: View {
    @Bindable var vm: GameViewModel
    let onTapCash: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            dateCell
            Spacer(minLength: 8)
            cashCell
                .onTapGesture { onTapCash() }
                .coachmarkAnchor(.cash)
                .coachmarkAnchor(.score)         // re-anchored — score lives in the P&L modal now
                .coachmarkAnchor(.pnlPanel)      // re-anchored — tapping cash opens the modal
                .coachmarkAnchor(.scoreSources)  // re-anchored — score breakdown is in the modal
            Spacer(minLength: 8)
            memoryCell   // v9 Prompt 4 Phase 5 — ambient memory-weight readout
            Spacer(minLength: 8)
            threatMeter
                .coachmarkAnchor(.threatMeter)
                // .watchList anchor lives on MallView now (Phase C) — warnings are ambient
                // on the scene via hazard/closing dots + wing tints.
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#14141a").opacity(0.96))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color(hex: "#3a3a48")), alignment: .bottom)
        .foregroundStyle(Color(hex: "#e8e8f0"))
    }

    // v9 Prompt 4 Phase 5 — total mall memory weight. Read-only, minimal.
    // Matches the ambient typography of the threat-reason label: monospaced,
    // muted color, tabular digits.
    private var memoryCell: some View {
        let total = Int(vm.state.totalMemoryWeight.rounded())
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("Memory")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color(hex: "#6a6a78"))
            Text("\(total)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Color(hex: "#b8e8f8"))
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Cells

    private var dateCell: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(GameConstants.months[vm.state.month]) \(String(vm.state.year))")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Color(hex: "#ff4dbd"))
            Text("MONTH \(monthsSurvived)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color(hex: "#6a6a78"))
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // Cash — big bold value. Debt shown as small red subscript beside cash when > 0.
    // Tapping the cell opens the P&L modal.
    //
    // v9 Prompt 15 Phase 1 — cash animates upward rather than jumping.
    // contentTransition(.numericText()) gives the iOS-17 counter-style
    // digit transition; the .animation modifier below drives it on
    // any state.cash mutation. 0.6s easeOut matches the economics
    // floating labels' drift window so HUD and scene feel synced.
    private var cashCell: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(fmt(vm.state.cash))
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(cashColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.6), value: vm.state.cash)
            if vm.state.debt > 0 {
                (Text("debt ").foregroundStyle(Color(hex: "#6a6a78"))
                 + Text("-\(fmt(vm.state.debt))").foregroundStyle(debtColor))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .monospacedDigit()
            }
        }
        .contentShape(Rectangle())   // make the whole cell (including padding) tappable
        .fixedSize(horizontal: true, vertical: false)
    }

    private var threatMeter: some View {
        let t = vm.state.threatMeter
        let band = Threat.band(t)
        let fillColor: Color = {
            switch band {
            case .stable, .uneasy: return Color(hex: "#5DCAA5")
            case .risky:           return Color(hex: "#ff4dbd")
            case .critical:        return Color(hex: "#ff2f4a")
            }
        }()
        return HStack(spacing: 6) {
            Text(band.displayName.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.8)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Capsule().fill(fillColor.opacity(0.25)))
                .foregroundStyle(fillColor)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#0a0a0e")).overlay(
                        Capsule().strokeBorder(Color(hex: "#2a2a34"), lineWidth: 1)
                    )
                    Capsule().fill(fillColor).frame(width: geo.size.width * t)
                }
            }
            .frame(width: 140, height: 10)
        }
    }

    // MARK: - Derived values

    // (year - startingYear) * 12 + month + 1 — so the game starts at MONTH 1 rather
    // than MONTH 0. This is the game's north-star number: "how long have I lasted?".
    private var monthsSurvived: Int {
        (vm.state.year - GameConstants.startingYear) * 12 + vm.state.month + 1
    }

    private var cashColor: Color {
        if vm.state.cash > 5000 { return Color(hex: "#9FE1CB") }
        if vm.state.cash > 1500 { return Color(hex: "#7fd3f0") }
        return Color(hex: "#ff4dbd")
    }

    private var debtColor: Color {
        if vm.state.debt > 15000 { return Color(hex: "#ff4dbd") }
        if vm.state.debt > 0     { return Color(hex: "#7fd3f0") }
        return Color(hex: "#9FE1CB")
    }

    // Short money format — $1.2k / $2.5M / $850.
    private func fmt(_ n: Int) -> String {
        let v = abs(n)
        if v >= 1_000_000 {
            return "$" + String(format: "%.1fM", Double(v) / 1_000_000)
        }
        if v >= 10_000 {
            return "$" + String(format: "%.0fk", Double(v) / 1_000)
        }
        if v >= 1_000 {
            return "$" + String(format: "%.1fk", Double(v) / 1_000)
        }
        return "$\(v)"
    }
}
