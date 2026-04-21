import SwiftUI

// v9 Prompt 3 followup — top-level HUD shortcut. Sits directly above the
// MANAGE button in the bottom-left corner. Style matches MANAGE exactly
// (same pink border, same black fill, same dimensions) so the pair reads
// as siblings. Opens ArtifactAcquireSheet — same content as the Acquire
// tab inside MANAGE, without going through the drawer.
struct AcquireButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("ACQUIRE")
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
