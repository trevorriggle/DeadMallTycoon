import SwiftUI

// v9 Prompt 19 — the dedicated sealing surface. Three sections: Wings,
// Entrances, Storefronts. Each section lists eligible candidates with a
// one-line savings preview; tapping a seal button routes to
// vm.requestSeal(...) which raises SealConfirmOverlay in MallView.
//
// Sheet stays open after confirming a seal — the player can seal several
// candidates in one visit. Only the confirmation overlay dismisses on
// confirm; this sheet remains mounted, and the lists refresh because they
// read from vm.state on each render (SwiftUI Observation drives rebuild
// when pendingSealAction flips back to nil and the underlying state
// mutates).
struct SealingSheet: View {
    @Bindable var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider().background(Color(hex: "#3a3a48"))
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        wingsSection
                        entrancesSection
                        storefrontsSection
                    }
                    .padding(16)
                }
            }
            .background(Color(hex: "#14141a"))
            // v9 Prompt 19 — SealConfirmOverlay is also mounted in MallView
            // for the ArtifactInfoCard path, but SwiftUI presents sheets
            // ABOVE the content view, so a MallView-level overlay would
            // render behind this sheet. Mount the same overlay here so
            // confirming from within the sheet is visible; the overlay
            // itself is defensive (no-ops when pendingSealAction is nil),
            // so having two mount sites is safe. Sheet stays open across
            // confirms by design — only the overlay dismisses on confirm.
            if vm.state.pendingSealAction != nil {
                SealConfirmOverlay(vm: vm)
                    .transition(.opacity)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // Reuses the decision-sheet pause pattern. If the confirmation
        // overlay is mounted on top of us, pause stays held (we own it;
        // the overlay doesn't touch pause state).
        .onAppear    { vm.pauseForDecisionSheet() }
        .onDisappear { vm.resumeFromDecisionSheet() }
    }

    private var header: some View {
        HStack {
            Text("SEAL")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(hex: "#b8e8f8"))
            Spacer()
            Button("Close") { dismiss() }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#6a6a78"))
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
    }

    // MARK: — Wings

    private var wingsSection: some View {
        let wings = Sealing.eligibleWings(in: vm.state)
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("WINGS")
            if wings.isEmpty {
                sectionEmpty("Both wings already sealed.")
            } else {
                ForEach(wings, id: \.self) { wing in
                    wingRow(wing)
                }
            }
        }
    }

    private func wingRow(_ wing: Wing) -> some View {
        let action = SealAction.wing(wing)
        let savings = savingsFor(action)
        let label = wing == .north ? "North Wing" : "South Wing"
        let advisory = Sealing.wingOccupancyAdvisory(for: wing, in: vm.state)
        return sealRow(
            title: label,
            subtitle: advisory,
            savings: savings,
            action: action
        )
    }

    // MARK: — Entrances

    private var entrancesSection: some View {
        let entrances = Sealing.eligibleEntrances(in: vm.state)
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("ENTRANCES")
            if entrances.isEmpty {
                sectionEmpty("No open entrances remain.")
            } else {
                ForEach(entrances, id: \.self) { corner in
                    entranceRow(corner)
                }
            }
        }
    }

    private func entranceRow(_ corner: EntranceCorner) -> some View {
        let action = SealAction.entrance(corner)
        let savings = savingsFor(action)
        return sealRow(
            title: entranceName(corner),
            subtitle: nil,
            savings: savings,
            action: action
        )
    }

    // MARK: — Storefronts (memorials)

    private var storefrontsSection: some View {
        let storefronts = Sealing.eligibleStorefronts(in: vm.state)
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("STOREFRONTS")
            if storefronts.isEmpty {
                sectionEmpty("No boarded storefronts to seal yet — closures and curated displays will appear here.")
            } else {
                ForEach(storefronts) { a in
                    storefrontRow(a)
                }
            }
        }
    }

    private func storefrontRow(_ a: Artifact) -> some View {
        let action = SealAction.memorial(artifactId: a.id)
        let savings = savingsFor(action)
        let sub: String? = {
            switch a.type {
            case .displaySpace: return "Currently a display space — sealing ends the display."
            default:            return nil
            }
        }()
        return sealRow(
            title: a.name,
            subtitle: sub,
            savings: savings,
            action: action
        )
    }

    // MARK: — shared row

    private func sealRow(title: String,
                        subtitle: String?,
                        savings: Int,
                        action: SealAction) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: "#d8d8e0"))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(Color(hex: "#9898a8"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if savings > 0 {
                    Text("Saves $\(fmt(savings))/mo")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#7fe0a0"))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            Button("Seal…") { vm.requestSeal(action) }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color(hex: "#b8e8f8"))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color(hex: "#1a1a22"))
                .overlay(RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color(hex: "#7fa0b0"), lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color(hex: "#0e0e14"))
        .overlay(RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(hex: "#2a2a34"), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(1.8)
            .foregroundStyle(Color(hex: "#7fa0b0"))
    }

    private func sectionEmpty(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, design: .serif))
            .italic()
            .foregroundStyle(Color(hex: "#6a6a78"))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#0e0e14"))
            .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color(hex: "#2a2a34"), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: — helpers

    private func savingsFor(_ action: SealAction) -> Int {
        let current = Economy.operatingCost(vm.state)
        let projected = Economy.hypotheticalOperatingCost(vm.state, ifApplying: action) ?? current
        return max(0, current - projected)
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
