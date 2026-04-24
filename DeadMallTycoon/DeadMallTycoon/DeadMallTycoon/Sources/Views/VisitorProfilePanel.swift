import SwiftUI

// v9 Prompt 4 Phase 6 — visitor profile panel.
//
// Renders in the dead space beneath the aspect-fit mall scene (see
// SCREENSHOT.png). Overlay only — does NOT shift the HUD or mall scene.
// Visible when state.selectedVisitorIdentity is set (populated by
// vm.selectVisitor, cleared by vm.clearSelection). Read-only by design:
// the Prompt 4 non-goal note explicitly excludes player actions mutating
// visitor state from this panel.
//
// Typography and palette match the HUD (monospaced labels, italic serif for
// thought text) — this is an inhabitant of the HUD, not a modal.
struct VisitorProfilePanel: View {
    @Bindable var vm: GameViewModel

    var body: some View {
        Group {
            if let identity = vm.state.selectedVisitorIdentity {
                card(for: identity)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                EmptyView()
            }
        }
    }

    private func card(for v: VisitorIdentity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Name row + close
            HStack(alignment: .firstTextBaseline) {
                Text(v.name)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(Color(hex: "#b8e8f8"))
                Text("· age \(v.age)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(hex: "#6a6a78"))
                Spacer()
                Button(action: { vm.clearSelection() }) {
                    Text("×")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#6a6a78"))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }

            // Cohort
            Text(v.ageCohort.displayName.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#ff4dbd"))

            // State lines
            HStack(spacing: 14) {
                stat("MOOD", v.mood.displayName)
                stat("DOING", v.activity.displayName)
            }
            stat("HEADING", destinationLabel(v.destinationIntent))

            // Last overheard thought — italic, quoted.
            if !v.lastMemory.isEmpty {
                Divider().background(Color(hex: "#3a3a48")).padding(.vertical, 2)
                Text("“\(v.lastMemory)”")
                    .font(.system(size: 13, design: .default)).italic()
                    .foregroundStyle(Color(hex: "#d8d8e0"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: 420, alignment: .leading)
        .background(Color(hex: "#14141a").opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(hex: "#3a3a48"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color(hex: "#6a6a78"))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#e8e8f0"))
        }
    }

    // Resolves a DestinationIntent to a human-readable line. The `.store`
    // case looks up the tenant name from state for flavor ("Heading to
    // Brinkerhoff Books") when the slot is populated.
    private func destinationLabel(_ intent: DestinationIntent) -> String {
        switch intent {
        case .store(let slotId):
            if let store = vm.state.stores.first(where: { $0.id == slotId }),
               store.tier != .vacant, !store.name.isEmpty {
                return store.name
            }
            return "A store"
        default:
            return intent.displayLabel
        }
    }
}
