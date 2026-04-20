import SwiftUI

// Last-12-months score trend. Relocated out of HUDView during the Phase A UI
// overhaul so it can live inside the P&L modal in Phase B without the top strip
// needing to depend on it.
struct ScoreSparklineView: View {
    let history: RingBuffer<Int>

    var body: some View {
        Canvas { ctx, size in
            let values = history.values
            guard values.count >= 2 else {
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
            let first = values.first ?? 0
            let last = values.last ?? 0
            let color: Color = last > first ? Color(hex: "#9FE1CB")
                             : last < first ? Color(hex: "#F09595")
                             : Color(hex: "#FAC775")
            ctx.stroke(path, with: .color(color), lineWidth: 1.5)
        }
    }
}

// Helper: init Color from hex. Lives here (rather than in HUDView) because
// the hex constructor is used across every view in the app.
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
