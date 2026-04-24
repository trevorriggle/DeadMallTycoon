import SwiftUI

// v9 Prompt 19 — top-level HUD shortcut for the sealing sheet. Sits in
// the same bottom-left stack as ACQUIRE and MANAGE. Style matches its
// siblings except for the border — sealing is a considered, economic
// action, not an alarming one, so the border is a cooler blue-gray
// (#7fa0b0) to differentiate it from the bright pink action buttons
// without leaving the palette.
struct SealButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("SEAL")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color(hex: "#b8e8f8"))
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(Color(hex: "#2a0a1a").opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: "#7fa0b0"), lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
