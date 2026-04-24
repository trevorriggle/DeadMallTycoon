import SwiftUI

// v8: the yellow/red decision strip that appears pinned at the top of the world view
// when a tenant offer or flavor event needs a choice. Play is paused until resolved.
struct DecisionBanner: View {
    @Bindable var vm: GameViewModel
    let decision: Decision

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch decision {
            case .tenant(let offer):
                tenantOffer(offer)
            case .event(let event):
                flavorEvent(event)
            }
        }
        .padding(10)
        .frame(maxWidth: 440)
        .background(backgroundColor)
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(borderColor, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.6), radius: 10, y: 3)
    }

    private func tenantOffer(_ o: TenantOffer) -> some View {
        // v9 Prompt 6 — resolve the memorial cost of accepting this offer
        // (nil for fresh vacancies or offers with no compatible slot).
        let memorial = StoreActions.memorialCost(for: o, in: vm.state)

        return VStack(alignment: .leading, spacing: 6) {
            Text("TENANT OFFER · PAUSED")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color(hex: "#7fd3f0"))
            Text(o.name).font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: "#b8e8f8"))
            Text(o.pitch)
                .font(.system(size: 15, design: .default))
                .foregroundStyle(Color(hex: "#d8d8e0"))
            Text("\(o.tier.rawValue) · \(o.lease)mo lease")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#6a6a78"))

            if let m = memorial {
                memorialCostRow(m)
            }

            HStack(spacing: 8) {
                decisionButton(primary: true,
                               title: "Sign",
                               subtitle: "+$\(o.rent)/mo · less score") { vm.acceptDecision() }
                decisionButton(primary: false,
                               title: "Decline",
                               subtitle: "Keep empty") { vm.declineDecision() }
            }
            .padding(.top, 4)
        }
    }

    // v9 Prompt 6 — memorial-cost row. Surfaces what the player is about
    // to destroy by signing this offer. Live numbers: years since the
    // boardedStorefront was spawned, its accumulated memoryWeight, and
    // the raw count of visitor thoughts that have referenced it.
    private func memorialCostRow(_ m: MemorialCost) -> some View {
        let years = m.yearsBoarded == 1 ? "1 year" : "\(m.yearsBoarded) years"
        let weight = Int(m.memoryWeight.rounded())
        let thoughts = m.thoughtReferenceCount
        let thoughtWord = thoughts == 1 ? "visitor thought" : "visitor thoughts"
        return VStack(alignment: .leading, spacing: 3) {
            Text("ACCEPTING DESTROYS THIS MEMORY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color(hex: "#ff4dbd"))
            Text("\(m.tenantName) · boarded \(years) · memory weight \(weight) · \(thoughts) \(thoughtWord)")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(Color(hex: "#d8d8e0"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#2a0a1a"))
        .overlay(RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color(hex: "#5a2a4a"), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .padding(.top, 2)
    }

    private func flavorEvent(_ ev: FlavorEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DISASTER · PAUSED")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color(hex: "#ff4dbd"))
            Text(ev.name).font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: "#b8e8f8"))
            Text(ev.description)
                .font(.system(size: 15, design: .default))
                .foregroundStyle(Color(hex: "#d8d8e0"))
            HStack(spacing: 8) {
                decisionButton(primary: true,
                               title: ev.acceptLabel,
                               subtitle: nil) { vm.acceptDecision() }
                decisionButton(primary: false,
                               title: ev.declineLabel,
                               subtitle: nil) { vm.declineDecision() }
            }
            .padding(.top, 4)
        }
    }

    // Large outcome-summarizing button. Primary = green sign/accept, secondary = muted decline.
    private func decisionButton(primary: Bool, title: String, subtitle: String?,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .tracking(0.6)
                if let s = subtitle {
                    Text(s)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(0.4)
                        .opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(primary ? Color(hex: "#0a1f10") : Color(hex: "#e8e8f0"))
            .background(primary ? Color(hex: "#5DCAA5") : Color(hex: "#1a1a22"))
            .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(primary ? Color(hex: "#2a8a70") : Color(hex: "#3a3a48"),
                                      lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        switch decision {
        case .tenant: return Color(hex: "#1a1a22")
        case .event:  return Color(hex: "#2a0a1a")
        }
    }
    private var borderColor: Color {
        switch decision {
        case .tenant: return Color(hex: "#7fd3f0")
        case .event:  return Color(hex: "#ff4dbd")
        }
    }
}

// MARK: - Start screen

// v9 Prompt 18 — rebuilt. The start screen now presents the title and
// two top-level actions: "New Mall" (opens NewMallSheet, where the
// player chooses tutorial on/off) and "How to Play" (opens
// HowToPlayView directly, no run started). The old inline
// "Begin / Skip Tutorial" pair moved into NewMallSheet so the
// tutorial choice is an explicit decision, not a hidden toggle.
struct StartScreenView: View {
    // tutorialEnabled=true → run starts paused on the .welcome beat
    // and subsequent beats fire as their triggers occur.
    // tutorialEnabled=false → no beats fire for this run (SC4 parity).
    let onStart: (_ tutorialEnabled: Bool) -> Void
    @State private var showingNewMall = false
    @State private var showingHowToPlay = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#0a0a0e"), Color(hex: "#14141a"), Color(hex: "#0a0a0e")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image("TitleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 480)
                    .accessibilityLabel("Dead Mall Tycoon")
                Text("KEEP THE CORPSE BREATHING.")
                    .font(.system(size: 15, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Color(hex: "#6a6a78"))
                    .padding(.top, 8)
                Text("""
                You inherit the mall. Score grows with empty stores, sealed wings, and visible \
                decay. Cash comes only from tenants. Full occupancy is a losing run. Total \
                collapse is a losing run. The goal is the long, slow middle — a mall that \
                should have closed years ago but somehow hasn't.
                """)
                    .font(.system(size: 17, design: .default))
                    .italic()
                    .foregroundStyle(Color(hex: "#d8d8e0"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 520)
                    .padding(.top, 8)
                Button("New Mall") { showingNewMall = true }
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: "#2a0a2a"))
                    .padding(.horizontal, 36).padding(.vertical, 14)
                    .background(Color(hex: "#ff4dbd"))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color(hex: "#5a2a4a"), lineWidth: 2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                Button("How to Play") { showingHowToPlay = true }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: "#7fd3f0"))
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color(hex: "#2a6a8a")))
                    .padding(.top, 2)
            }
        }
        .sheet(isPresented: $showingNewMall) {
            NewMallSheet(
                onStart: { tutorialEnabled in
                    showingNewMall = false
                    onStart(tutorialEnabled)
                },
                onOpenHowToPlay: {
                    showingNewMall = false
                    showingHowToPlay = true
                },
                onCancel: { showingNewMall = false }
            )
        }
        .sheet(isPresented: $showingHowToPlay) {
            HowToPlayView(onClose: { showingHowToPlay = false })
        }
    }
}

// MARK: - Game over

// v9 Prompt 9 Phase B — the end screen is the ledger.
//
// The run's story outweighs its number: the scrollable LedgerView fills
// the screen, and the final score shrinks to a one-line footer above the
// Try Again button. Per ENDGAME.md, the ledger "tells the story of this
// mall: every tenant that left, every artifact that decayed, every wing
// that went dark, every visitor that remembered something specific."
// Score is a footnote.
//
// Pre-Phase-9 design (big red FORECLOSED + 64pt score) is gone. The
// bankruptcy framing stays as a compact header — "FORECLOSED" still
// opens the screen so the player knows what happened — but under it is
// the ledger, not the number.
struct GameOverView: View {
    @Bindable var vm: GameViewModel

    private var yearsSurvived: Int { vm.state.year - GameConstants.startingYear }

    // v9 Prompt 14 — reason-driven header copy.
    private var headline: String {
        switch vm.state.gameOverReason {
        case .forgotten:        return "FORGOTTEN"
        case .bankruptcy, nil:  return "FORECLOSED"
        }
    }

    private var subtitle: String {
        switch vm.state.gameOverReason {
        case .forgotten:
            return "The mall forgot itself. Below is what happened."
        case .bankruptcy, nil:
            return "The bank took the mall. Below is what happened."
        }
    }

    // FORECLOSED in the old red-alert color; FORGOTTEN in a cooler,
    // more grieving tone — the mall didn't fail, it just stopped
    // being held in anyone's mind.
    private var headlineColor: Color {
        switch vm.state.gameOverReason {
        case .forgotten:        return Color(hex: "#7a8ca0")
        case .bankruptcy, nil:  return Color(hex: "#ff2f4a")
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Compact header — 24pt, not 42pt. Headline owns its line
            // but doesn't dominate the screen. Subtitle is one
            // sentence of context, not a dramatic beat. Copy branches
            // on gameOverReason — "FORECLOSED" for economic failure,
            // "FORGOTTEN" for the Prompt 14 memory failure mode. Nil
            // reason (shouldn't happen post-Prompt-14 but defensive)
            // defaults to the FORECLOSED framing.
            VStack(spacing: 4) {
                Text(headline)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(headlineColor)
                Text(subtitle)
                    .font(.system(size: 13, design: .default)).italic()
                    .foregroundStyle(Color(hex: "#d8d8e0"))
            }
            .padding(.top, 24).padding(.bottom, 14)

            Divider().background(Color(hex: "#3a3a48"))

            // The ledger. Primary content. Scrolls freely; fills every
            // pixel between the header and footer that isn't already
            // reserved.
            //
            // v9 Prompt 9 Phase C — deliberately non-interactive
            // (onEntryTap is the default nil). At game over the mall is
            // frozen AND the GameOverView covers it at 0.97 opacity, so
            // the scene-pulse Phase C renders would be invisible. The
            // end-screen is a reading surface — rows stay plain text.
            // Users inspecting where an artifact IS on the mall use the
            // mid-game History tab, not this one.
            ScrollView {
                LedgerView(
                    entries: vm.state.ledger,
                    emptyStateText: "Nothing happened worth remembering."
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }

            Divider().background(Color(hex: "#3a3a48"))

            // Footer — small score line, survival span, Try Again.
            // Score is 12pt monospace, not 64pt. The number is a
            // footnote to the narrative above.
            VStack(spacing: 12) {
                HStack {
                    Text("Final score · \(vm.state.score.formatted())")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Color(hex: "#7fd3f0"))
                    Spacer()
                    Text("\(yearsSurvived)y \(vm.state.month)mo survived")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color(hex: "#6a6a78"))
                }
                .padding(.horizontal, 24)

                Button("Try Again") {
                    vm.restart()
                }
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Color(hex: "#2a0a2a"))
                .padding(.horizontal, 28).padding(.vertical, 10)
                .background(Color(hex: "#ff4dbd"))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#5a2a4a"), lineWidth: 2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .buttonStyle(.plain)
            }
            .padding(.top, 14).padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.97))
    }
}
