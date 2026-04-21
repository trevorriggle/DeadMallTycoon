import SwiftUI

// Bottom-left pill that opens the MANAGE drawer (Tenants/Promos/Staff/Wings/Ads/Build).
// Replaces the old five-tab TabBar from Phase 1-5.
struct ManageButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("MANAGE")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color(hex: "#b8e8f8"))
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(Color(hex: "#2a0a1a").opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: "#ff4dbd"), lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
