import SwiftUI

// v9 Prompt 18 Phase B — "New Mall" decision sheet.
//
// Presented from the start screen when the player taps "Begin Run."
// Two primary choices — tutorial on, tutorial off — plus a secondary
// How to Play entry that opens the reader without starting a run.
// Chose a sheet rather than inline start-screen buttons so the pair
// of choices is unambiguous (tutorial is an opt-in decision, not a
// toggle hidden on the title).
struct NewMallSheet: View {
    let onStart: (_ tutorialEnabled: Bool) -> Void
    let onOpenHowToPlay: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            header

            Text("""
                The tutorial is a small in-run card that pauses the game at \
                key moments to explain a mechanic. Each beat fires at most \
                once per run. You can skip it now and still open How to Play \
                at any time from the MANAGE drawer.
                """)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(Color(hex: "#d8d8e0"))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)

            VStack(spacing: 12) {
                primaryButton(title: "Begin Run · Tutorial On",
                              subtitle: "Guided by in-run beats.",
                              action: { onStart(true) })
                primaryButton(title: "Begin Run · No Tutorial",
                              subtitle: "Straight into the mall.",
                              action: { onStart(false) })
                Button("Read How to Play", action: onOpenHowToPlay)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: "#7fd3f0"))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color(hex: "#2a6a8a"), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .buttonStyle(.plain)
            }

            Spacer().frame(height: 4)

            Button("Cancel", action: onCancel)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color(hex: "#6a6a78"))
        }
        .padding(30)
        .frame(maxWidth: 520)
        .background(Color(hex: "#14141a"))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color(hex: "#8a2a6a"), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("NEW MALL")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color(hex: "#ff4dbd"))
            Text("JANUARY 1982")
                .font(.system(size: 12, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(hex: "#6a6a78"))
        }
    }

    private func primaryButton(title: String,
                               subtitle: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .tracking(1)
                Text(subtitle)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.4)
                    .opacity(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .foregroundStyle(Color(hex: "#2a0a2a"))
            .background(Color(hex: "#ff4dbd"))
            .overlay(RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color(hex: "#5a2a4a"), lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
