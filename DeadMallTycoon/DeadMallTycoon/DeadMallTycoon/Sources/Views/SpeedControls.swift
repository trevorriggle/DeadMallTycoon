import SwiftUI

// Bottom-right floating speed controls. Pause · 1× · 2× · 4× · 8×.
// Extracted out of the old HUDView during the Phase A UI overhaul so the
// top strip can stay thin (40pt) and controls can float over the scene per
// tycoon-game convention (Theme Hospital, Two Point Hospital).
struct SpeedControls: View {
    @Bindable var vm: GameViewModel

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Speed.allCases, id: \.rawValue) { s in
                Button {
                    vm.setSpeed(s)
                } label: {
                    Text(label(for: s))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .frame(minWidth: 28, minHeight: 28)
                        .foregroundStyle(vm.state.speed == s ? Color(hex: "#9FE1CB") : Color(hex: "#888780"))
                        .background(vm.state.speed == s ? Color(hex: "#2a4a5a") : Color(hex: "#1a1917").opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#444441")))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(hex: "#0a0908").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
}
