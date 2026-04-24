import SwiftUI

// v9 Prompt 7 — seal confirmation dialog.
// v9 Prompt 19 — generalized across all three seal kinds (memorial, wing,
// entrance). Dispatches on vm.state.pendingSealAction; each case renders a
// slightly different card (title + consequences + savings line), but the
// skeleton, cancel/confirm buttons, and the permanence warning are shared.
//
// Mounted in MallView as a full overlay when GameState.pendingSealAction
// is non-nil. Obeys the Phase 0 overlay-only invariant from Prompt 4: the
// mall scene and HUD positions do not shift when this appears or dismisses.
//
// Copy is placeholder for memorial seal flavor — marked `[copy pending]`.
// Wing and entrance card copy is minimal and functional; no flavor layer
// planned for those cases.
struct SealConfirmOverlay: View {
    @Bindable var vm: GameViewModel

    var body: some View {
        if let action = vm.state.pendingSealAction {
            overlay(for: action)
        }
    }

    private func overlay(for action: SealAction) -> some View {
        VStack {
            Spacer()
            card(for: action)
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.55).ignoresSafeArea())
    }

    // The shared card shell. Content varies by action; the savings preview
    // is always rendered from Economy.hypotheticalOperatingCost so the math
    // matches the actual post-seal state.
    @ViewBuilder
    private func card(for action: SealAction) -> some View {
        let title = cardTitle(for: action)
        let subtitle = cardSubtitle(for: action)
        let consequence = cardConsequence(for: action)
        let current = Economy.operatingCost(vm.state)
        let projected = Economy.hypotheticalOperatingCost(vm.state, ifApplying: action) ?? current
        let savings = max(0, current - projected)

        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(Color(hex: "#ff4dbd"))
            Text(subtitle)
                .font(.system(size: 22, weight: .black, design: .serif))
                .foregroundStyle(Color(hex: "#b8e8f8"))
            if let consequence {
                Text(consequence)
                    .font(.system(size: 15, design: .serif))
                    .italic()
                    .foregroundStyle(Color(hex: "#d8d8e0"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            costPreview(current: current, projected: projected, savings: savings)

            Text(permanenceWarning(for: action))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#ffd477"))
                .padding(.top, 2)

            HStack(spacing: 10) {
                Button("Cancel") { vm.cancelSealConfirmation() }
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(Color(hex: "#d8d8e0"))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color(hex: "#1a1a22"))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color(hex: "#3a3a48"), lineWidth: 1.5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .buttonStyle(.plain)
                Spacer(minLength: 0)
                Button(confirmLabel(for: action)) { vm.confirmSeal() }
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(Color(hex: "#2a0a2a"))
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Color(hex: "#ff4dbd"))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color(hex: "#5a2a4a"), lineWidth: 2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color(hex: "#14141a"))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(hex: "#8a2a6a"), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.7), radius: 20, y: 6)
    }

    // Three lines: current ops, projected ops, monthly savings highlighted.
    private func costPreview(current: Int, projected: Int, savings: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Current operating cost")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(hex: "#9898a8"))
                Spacer()
                Text("$\(fmt(current))/mo")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#d8d8e0"))
            }
            HStack {
                Text("After sealing")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(hex: "#9898a8"))
                Spacer()
                Text("$\(fmt(projected))/mo")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#d8d8e0"))
            }
            HStack {
                Text("Monthly savings")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#7fe0a0"))
                Spacer()
                Text(savings > 0 ? "−$\(fmt(savings))/mo" : "—")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(hex: "#7fe0a0"))
            }
        }
        .padding(10)
        .background(Color(hex: "#0e0e14"))
        .overlay(RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(hex: "#2a2a34"), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: — per-action copy

    private func cardTitle(for action: SealAction) -> String {
        switch action {
        case .memorial: return "SEAL THIS SPACE?"
        case .wing:     return "SEAL THIS WING?"
        case .entrance: return "SEAL THIS ENTRANCE?"
        }
    }

    private func cardSubtitle(for action: SealAction) -> String {
        switch action {
        case .memorial(let artifactId):
            return vm.state.artifacts.first(where: { $0.id == artifactId })?.name
                ?? "Unknown Memorial"
        case .wing(let wing):
            return wing == .north ? "North Wing" : "South Wing"
        case .entrance(let corner):
            return entranceName(corner)
        }
    }

    // One-line consequence, rendered italic in the flavor slot. Returns nil
    // when there's nothing to say (clean entrance seal, etc.).
    private func cardConsequence(for action: SealAction) -> String? {
        switch action {
        case .memorial:
            return "[copy pending — seal confirmation flavor]"
        case .wing(let wing):
            let n = Sealing.activeTenantCount(in: wing, vm.state)
            if n == 0 {
                return "The wing is already empty. Sealing cuts its operating overhead."
            } else if n == 1 {
                return "One active tenant will close. The wing's traffic drops to zero."
            } else {
                return "\(n) active tenants will close. The wing's traffic drops to zero."
            }
        case .entrance:
            return "Visitors no longer enter from this corner. Wing entrances on the opposite side continue to function."
        }
    }

    private func permanenceWarning(for action: SealAction) -> String {
        switch action {
        case .memorial: return "SEALING IS PERMANENT · NO RE-OPEN · MEMORY ACCRUAL DROPS TO 0.5×"
        case .wing:     return "SEALING IS PERMANENT · WING CANNOT BE RE-OPENED"
        case .entrance: return "SEALING IS PERMANENT · ENTRANCE CANNOT BE RE-OPENED"
        }
    }

    private func confirmLabel(for action: SealAction) -> String {
        switch action {
        case .memorial: return "Seal Permanently"
        case .wing:     return "Seal Wing"
        case .entrance: return "Seal Entrance"
        }
    }

    private func entranceName(_ corner: EntranceCorner) -> String {
        switch corner {
        case .nw: return "Northwest Entrance"
        case .ne: return "Northeast Entrance"
        case .sw: return "Southwest Entrance"
        case .se: return "Southeast Entrance"
        }
    }

    private func fmt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
}
