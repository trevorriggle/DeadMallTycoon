import SwiftUI

// Top stats bar — date, cash, debt, score, threat meter, speed buttons.
// Matches v8's .hud row at the top of the page.
// Responsive: on regular width (iPad landscape/portrait) everything sits in a
// single row; on compact width (iPhone, narrow iPad split) the bar reflows into
// two rows so every value stays visible without horizontal scrolling.
struct HUDView: View {
    @Bindable var vm: GameViewModel
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        Group {
            if hSize == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "#1a1917"))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color(hex: "#3a3935")), alignment: .bottom)
        .foregroundStyle(Color(hex: "#e8dcc8"))
    }

    // Wide one-line HUD for iPad-scale widths.
    private var regularLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            dateCell(compact: false)
            statCell("CASH",  value: fmt(vm.state.cash),  color: cashColor)
                .coachmarkAnchor(.cash)
            if vm.state.debt > 0 {
                statCell("DEBT", value: fmt(vm.state.debt), color: debtColor)
            }
            statCell("SCORE", value: fmtScore(vm.state.score), color: Color(hex: "#FAC775"))
                .coachmarkAnchor(.score)
            ScoreSparklineView(history: vm.state.scoreHistory)
                .frame(width: 110, height: 36)
            threatMeter(compact: false)
                .coachmarkAnchor(.threatMeter)
            Spacer()
            speedButtons(compact: false)
        }
    }

    // Two-row HUD for iPhone / narrow-split widths. Priority stats up top, sparkline
    // + threat + speed controls on the second row. Cells are slightly smaller so
    // three fit on an iPhone portrait (~390pt) without clipping.
    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                dateCell(compact: true)
                statCell("CASH", value: fmt(vm.state.cash), color: cashColor, compact: true)
                    .coachmarkAnchor(.cash)
                if vm.state.debt > 0 {
                    statCell("DEBT", value: fmt(vm.state.debt), color: debtColor, compact: true)
                }
                statCell("SCORE", value: fmtScore(vm.state.score),
                         color: Color(hex: "#FAC775"), compact: true)
                    .coachmarkAnchor(.score)
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                ScoreSparklineView(history: vm.state.scoreHistory)
                    .frame(width: 72, height: 26)
                threatMeter(compact: true)
                    .coachmarkAnchor(.threatMeter)
                Spacer(minLength: 0)
                speedButtons(compact: true)
            }
        }
    }

    // Dashboard-style cell: small muted label on top, big bold value below.
    // Much more legible at a glance than the old inline label+value pairs.
    private func statCell(_ label: String, value: String, color: Color, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#888780"))
            Text(value)
                .font(.system(size: compact ? 22 : 26, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func dateCell(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("DATE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#888780"))
            Text("\(GameConstants.months[vm.state.month]) \(String(vm.state.year))")
                .font(.system(size: compact ? 18 : 22, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Color(hex: "#c4919a"))
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func threatMeter(compact: Bool) -> some View {
        let t = vm.state.threatMeter
        let band = Threat.band(t)
        let fillColor: Color = {
            switch band {
            case .stable, .uneasy: return Color(hex: "#5DCAA5")
            case .risky:           return Color(hex: "#EF9F27")
            case .critical:        return Color(hex: "#e24b4a")
            }
        }()
        let barWidth: CGFloat = compact ? 120 : 160
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("THREAT")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: "#888780"))
                Text(band.displayName.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(fillColor.opacity(0.25)))
                    .foregroundStyle(fillColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#0a0908")).overlay(
                        Capsule().strokeBorder(Color(hex: "#2a2a22"), lineWidth: 1)
                    )
                    Capsule().fill(fillColor)
                        .frame(width: geo.size.width * t)
                }
            }
            .frame(width: barWidth, height: 18)
        }
    }

    private func speedButtons(compact: Bool) -> some View {
        HStack(spacing: compact ? 2 : 3) {
            ForEach(Speed.allCases, id: \.rawValue) { s in
                Button {
                    vm.setSpeed(s)
                } label: {
                    Text(label(for: s))
                        .font(.system(size: compact ? 12 : 15, design: .monospaced))
                        .monospacedDigit()
                        .padding(.horizontal, compact ? 5 : 8)
                        .padding(.vertical, compact ? 2 : 3)
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

    // Short money format — $1.2k / $2.5M / $850 (no suffix under 1k).
    // Vastly easier to scan than "$1,234,567" when values get large.
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

    // Score uses the same K/M shaping but without the $ prefix.
    private func fmtScore(_ n: Int) -> String {
        let v = abs(n)
        if v >= 1_000_000 { return String(format: "%.1fM", Double(v) / 1_000_000) }
        if v >= 10_000    { return String(format: "%.0fk", Double(v) / 1_000) }
        if v >= 1_000     { return String(format: "%.1fk", Double(v) / 1_000) }
        return "\(v)"
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
