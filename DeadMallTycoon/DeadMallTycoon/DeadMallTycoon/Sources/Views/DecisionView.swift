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
                .font(.system(size: 15, design: .serif))
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
                .font(.system(size: 15, design: .serif))
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

struct StartScreenView: View {
    // withTutorial=true → guided first-year tutorial (half-speed, welcome coachmark).
    // withTutorial=false → skip straight into a normal run at x1.
    let onStart: (_ withTutorial: Bool) -> Void
    @State private var showingTutorial = false

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
                    .font(.system(size: 17, design: .serif))
                    .italic()
                    .foregroundStyle(Color(hex: "#d8d8e0"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 520)
                    .padding(.top, 8)
                Button("Begin Run · Jan 1982") {
                    onStart(true)
                }
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#2a0a2a"))
                .padding(.horizontal, 36).padding(.vertical, 14)
                .background(Color(hex: "#ff4dbd"))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#5a2a4a"), lineWidth: 2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .buttonStyle(.plain)
                .padding(.top, 20)
                Button("Skip Tutorial") { onStart(false) }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: "#6a6a78"))
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(hex: "#3a3a48")))
                    .padding(.top, 2)
                Button("How to Play") { showingTutorial = true }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: "#ff4dbd"))
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(hex: "#8a2a6a")))
            }
        }
        .sheet(isPresented: $showingTutorial) {
            TutorialView(onClose: { showingTutorial = false })
        }
    }
}

// MARK: - Tutorial

struct TutorialView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HOW TO PLAY")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color(hex: "#ff4dbd"))
                Text("THE CONTROLLED DECLINE")
                    .font(.system(size: 14, design: .monospaced))
                    .tracking(2.4)
                    .foregroundStyle(Color(hex: "#6a6a78"))
            }

            section("The Core Loop",
                "You run a dying mall. Score comes from empty stores, sealed wings, and visible decay — the mall looking abandoned is what the game rewards. Cash comes only from tenants paying rent. Operating costs always exceed the rent a small mall generates, so you're always bleeding something.")
            section("Why \"Barely Open\" Wins",
                "A fully occupied mall produces zero score — nothing empty to count. A fully abandoned mall also produces zero score — no one to witness it. The sweet spot is somewhere in the middle: enough tenants to keep the lights on and traffic walking through, enough vacancy and decay to feel like a tomb.")
            section("Score = Empty × Time × Decay × Life",
                "Each month you earn points for every empty storefront and sealed wing, multiplied by how long you've survived, multiplied by the aesthetic decay of your decorations, multiplied by how \"alive\" the mall still is (traffic-based). Survive longer = more score. Let things rot = more score. But you must stay open.")
            section("Threat & Warnings",
                "The Threat meter fills based on your decisions: unrepaired hazards, sealed wings without security, prolonged low traffic. The Watch List tells you what's building. Warnings appear before disasters — read them. High threat = consequences incoming.")
            section("Ending The Run",
                "The bank takes the mall when your debt exceeds $25,000. That's the only failure state. Until then, every month alive adds to your score. The best runs are the ones that should have ended a decade ago but didn't.")

            Button("Got It") { onClose() }
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Color(hex: "#2a0a2a"))
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(Color(hex: "#ff4dbd"))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#5a2a4a"), lineWidth: 2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .buttonStyle(.plain)
        }
        .padding(30)
        .frame(maxWidth: 680)
        .background(Color(hex: "#14141a"))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: "#8a2a6a"), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color(hex: "#7fd3f0"))
            Text(body)
                .font(.system(size: 18, design: .serif))
                .foregroundStyle(Color(hex: "#d8d8e0"))
                .lineSpacing(2)
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

    var body: some View {
        VStack(spacing: 0) {

            // Compact header — 24pt, not 42pt. "FORECLOSED" owns its
            // line but doesn't dominate the screen. Subtitle is one
            // sentence of context, not a dramatic beat.
            VStack(spacing: 4) {
                Text("FORECLOSED")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color(hex: "#ff2f4a"))
                Text("The bank took the mall. Below is what happened.")
                    .font(.system(size: 13, design: .serif)).italic()
                    .foregroundStyle(Color(hex: "#d8d8e0"))
            }
            .padding(.top, 24).padding(.bottom, 14)

            Divider().background(Color(hex: "#3a3a48"))

            // The ledger. Primary content. Scrolls freely; fills every
            // pixel between the header and footer that isn't already
            // reserved.
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
