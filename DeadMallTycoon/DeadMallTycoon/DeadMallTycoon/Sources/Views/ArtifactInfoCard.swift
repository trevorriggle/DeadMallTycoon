import SwiftUI

// v8: the decoration-selected detail panel (formerly DecorationInfoCard).
// v9 Prompt 3 — renamed ArtifactInfoCard, reads state.artifacts and displays
// per-type info via ArtifactCatalog. Ambient types (cost == 0) still get a
// card — tap-to-inspect doesn't gate on placeability — but the repair/remove
// actions are omitted for them since they weren't player-placed.
struct ArtifactInfoCard: View {
    @Bindable var vm: GameViewModel
    let artifactId: Int

    var body: some View {
        if let a = vm.state.artifacts.first(where: { $0.id == artifactId }) {
            card(a)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder private func card(_ a: Artifact) -> some View {
        let info = ArtifactCatalog.info(a.type)
        let mult = a.condition >= 4
            ? info.ruinMult
            : info.baseMult * (1 + Double(a.condition) * 0.2)
        let isPlaceable = info.cost > 0

        VStack(alignment: .leading, spacing: 8) {
            header(typeName: info.name, conditionLabel: conditionLabel(a))

            Text(info.description)
                .font(.system(size: 13, design: .serif)).italic()
                .foregroundStyle(Color(hex: "#d8d8e0"))

            // Ambient types contribute no aesthetic multiplier yet (Prompt 5
            // wires memoryWeight into scoring). Hide the 0% row for clarity.
            if isPlaceable {
                statLine(label: "Multiplier",
                         value: "+\(Int((mult * 100).rounded()))%",
                         color: .yellow)
            }

            if a.hazard {
                statLine(label: "Monthly fine",
                         value: "-$\(500 + a.condition * 200)",
                         color: Color(hex: "#ff4dbd"))
            }

            // Actions — placeable artifacts can be repaired and removed.
            // Ambient / event-spawned ones (boardedStorefront, etc.) aren't
            // the player's to remove; no actions shown.
            if isPlaceable {
                Button("Repair ($\(info.repair))") { vm.repairArtifact(a.id) }
                    .buttonStyle(.bordered)
                    .disabled(vm.state.cash < info.repair)
                    .frame(maxWidth: .infinity)
                Button("Remove (free)") { vm.removeArtifact(a.id) }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
            }

            // v9 Prompt 7 — memorial verbs on former-tenant slots.
            //   boardedStorefront → [Seal…] + [Repurpose as Display]
            //   displaySpace      → [Seal…] + [Revert to Boarded]
            //   sealedStorefront  → read-only; no verbs (terminal state)
            switch a.type {
            case .boardedStorefront:
                verbsForBoarded(a)
            case .displaySpace:
                displayContentLabel(a)
                verbsForDisplay(a)
            case .sealedStorefront:
                Text("SEALED · TERMINAL")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: "#6a6a78"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            default:
                EmptyView()
            }
        }
        .padding(14)
        .frame(maxWidth: 360)
        .background(Color(hex: "#14141a"))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: "#3a3a48"), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.6), radius: 12, y: 4)
    }

    private func header(typeName: String, conditionLabel: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(typeName.uppercased())
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: "#7fd3f0"))
                Text(conditionLabel)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(hex: "#6a6a78"))
            }
            Spacer(minLength: 4)
            Button(action: { vm.clearSelection() }) {
                Text("×")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: "#6a6a78"))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
    }

    private func conditionLabel(_ a: Artifact) -> String {
        let condition = (Condition(rawValue: a.condition) ?? .pristine).name
        return a.hazard ? "\(condition) · HAZARD" : condition
    }

    private func statLine(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(Color(hex: "#6a6a78"))
            Spacer()
            Text(value).foregroundStyle(color).monospacedDigit()
        }
        .font(.system(size: 14, design: .monospaced))
    }

    // v9 Prompt 7 — verb buttons on boardedStorefront.
    private func verbsForBoarded(_ a: Artifact) -> some View {
        VStack(spacing: 6) {
            Button("Seal Permanently…") { vm.requestSealConfirmation(artifactId: a.id) }
                .buttonStyle(.bordered)
                .tint(Color(hex: "#ff4dbd"))
                .frame(maxWidth: .infinity)
            Button("Repurpose as Display") { vm.repurposeAsDisplay(artifactId: a.id) }
                .buttonStyle(.bordered)
                .tint(Color(hex: "#7fd3f0"))
                .frame(maxWidth: .infinity)
        }
    }

    // v9 Prompt 7 — verb buttons on displaySpace.
    private func verbsForDisplay(_ a: Artifact) -> some View {
        VStack(spacing: 6) {
            Button("Seal Permanently…") { vm.requestSealConfirmation(artifactId: a.id) }
                .buttonStyle(.bordered)
                .tint(Color(hex: "#ff4dbd"))
                .frame(maxWidth: .infinity)
            Button("Revert to Boarded") { vm.revertToBoarded(artifactId: a.id) }
                .buttonStyle(.bordered)
                .tint(Color(hex: "#d8d8e0"))
                .frame(maxWidth: .infinity)
        }
    }

    // v9 Prompt 7 — current display content label + tint swatch.
    @ViewBuilder
    private func displayContentLabel(_ a: Artifact) -> some View {
        if let content = a.displayContent {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: content.tintHex))
                    .frame(width: 14, height: 14)
                    .overlay(RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Color(hex: "#3a3a48"), lineWidth: 1))
                Text(content.displayName.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color(hex: "#7fd3f0"))
                Spacer(minLength: 0)
            }
        }
    }
}
