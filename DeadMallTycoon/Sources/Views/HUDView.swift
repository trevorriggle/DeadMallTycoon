import SwiftUI

// Top stats bar — date, cash, debt, score, multiplier, threat meter, speed buttons.
// Matches v8's .hud row at the top of the page.
struct HUDView: View {
    @Bindable var vm: GameViewModel

    var body: some View {
        HStack(spacing: 10) {
            dateChip
            Text("·").foregroundStyle(.secondary)
            stat("Cash", value: fmt(vm.state.cash), color: cashColor)
                .coachmarkAnchor(.cash)
            stat("Debt", value: fmt(vm.state.debt), color: debtColor)
            stat("Score", value: vm.state.score.formatted(), color: .yellow)
                .coachmarkAnchor(.score)
            stat("Mult", value: String(format: "%.1f×", Economy.aestheticMult(vm.state)), color: .yellow)
            ScoreSparklineView(history: vm.state.scoreHistory)
                .frame(width: 90, height: 30)
            threatMeter
                .coachmarkAnchor(.threatMeter)
            Spacer()
            speedButtons
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(hex: "#1a1917"))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color(hex: "#3a3935")), alignment: .bottom)
        .font(.system(size: 17, design: .monospaced))
        .foregroundStyle(Color(hex: "#e8dcc8"))
    }

    private var dateChip: some View {
        Text("\(GameConstants.months[vm.state.month]) \(String(vm.state.year))")
            .foregroundStyle(Color(hex: "#c4919a"))
            .monospacedDigit()
    }

    private func stat(_ label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 14, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color(hex: "#888780"))
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }

    private var threatMeter: some View {
        let t = vm.state.threatMeter
        let band = Threat.band(t)
        let fillColor: Color = {
            switch band {
            case .stable, .uneasy: return Color(hex: "#5DCAA5")
            case .risky:           return Color(hex: "#EF9F27")
            case .critical:        return Color(hex: "#e24b4a")
            }
        }()
        return HStack(spacing: 6) {
            Text("Threat").font(.system(size: 14)).tracking(0.5).foregroundStyle(Color(hex: "#888780"))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#0a0908")).overlay(
                        Capsule().strokeBorder(Color(hex: "#2a2a22"), lineWidth: 1)
                    )
                    Capsule().fill(fillColor)
                        .frame(width: geo.size.width * t)
                }
            }
            .frame(width: 130, height: 16)
            Text(band.displayName.uppercased())
                .font(.system(size: 13, weight: .bold))
                .tracking(0.5)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(fillColor.opacity(0.25)))
                .foregroundStyle(fillColor)
        }
    }

    private var speedButtons: some View {
        HStack(spacing: 3) {
            ForEach(Speed.allCases, id: \.rawValue) { s in
                Button {
                    vm.setSpeed(s)
                } label: {
                    Text(label(for: s))
                        .font(.system(size: 15, design: .monospaced))
                        .monospacedDigit()
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(vm.state.speed == s ? Color(hex: "#2a4a5a") : Color.clear)
                        .foregroundStyle(vm.state.speed == s ? Color(hex: "#9FE1CB") : Color(hex: "#888780"))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(hex: "#444441")))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func label(for s: Speed) -> String {
        switch s {
        case .paused: return "II"
        case .x1: return "1×"
        case .x2: return "2×"
        case .x4: return "4×"
        case .x8: return "8×"
        }
    }

    private var cashColor: Color {
        if vm.state.cash > 5000 { return Color(hex: "#9FE1CB") }
        if vm.state.cash > 1500 { return Color(hex: "#FAC775") }
        return Color(hex: "#F09595")
    }

    private var debtColor: Color {
        if vm.state.debt > 15000 { return Color(hex: "#F09595") }
        if vm.state.debt > 0     { return Color(hex: "#FAC775") }
        return Color(hex: "#9FE1CB")
    }

    private func fmt(_ n: Int) -> String {
        "$" + (abs(n)).formatted()
    }
}

// v9: last-12-months score trend
struct ScoreSparklineView: View {
    let history: RingBuffer<Int>

    var body: some View {
        Canvas { ctx, size in
            let values = history.values
            guard values.count >= 2 else {
                // flat line placeholder
                let y = size.height / 2
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(Color(hex: "#3a3935")), lineWidth: 1)
                return
            }
            let maxV = max(values.max() ?? 1, 1)
            let minV = min(values.min() ?? 0, 0)
            let range = CGFloat(max(maxV - minV, 1))
            let step = size.width / CGFloat(values.count - 1)
            var path = Path()
            for (i, v) in values.enumerated() {
                let x = CGFloat(i) * step
                let normalized = CGFloat(v - minV) / range
                let y = size.height - normalized * size.height
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else       { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            // trend color: compare last to first
            let first = values.first ?? 0
            let last = values.last ?? 0
            let color: Color = last > first ? Color(hex: "#9FE1CB")
                             : last < first ? Color(hex: "#F09595")
                             : Color(hex: "#FAC775")
            ctx.stroke(path, with: .color(color), lineWidth: 1.5)
        }
    }
}

// Helper: init Color from hex
extension Color {
    init(hex: String) {
        var cleaned = hex
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        let v = UInt32(cleaned, radix: 16) ?? 0
        self.init(red:   Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >>  8) & 0xFF) / 255,
                  blue:  Double( v        & 0xFF) / 255)
    }
}
