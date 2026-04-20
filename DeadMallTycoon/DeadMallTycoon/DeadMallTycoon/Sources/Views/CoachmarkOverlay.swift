import SwiftUI

// The first-year tutorial's visual layer. Renders a dim backdrop, a highlight
// around the anchored UI element (if any), and a card with copy + a Next/Got It
// button. Paged — a single TutorialStep can walk through multiple frames (e.g.
// .hud = cash → score → threat).
//
// New in the iOS port — no v8 equivalent.

struct CoachmarkFrame {
    let anchor: CoachmarkAnchor?   // nil = centered, no highlight
    let header: String?
    let body: String
}

enum CoachmarkScript {
    // The beat sheet. Copy is close to Trevor's spec; keep plain English.
    static func frames(for step: TutorialStep) -> [CoachmarkFrame] {
        switch step {
        case .welcomeIntro:
            return [
                CoachmarkFrame(
                    anchor: nil,
                    header: "WELCOME · JANUARY 1982",
                    body: "You inherited a mall. Your job is to let it die beautifully — empty stores score points, but tenants pay the bills. Find the edge."
                )
            ]
        case .hud:
            return [
                CoachmarkFrame(
                    anchor: .cash, header: "YOUR MONEY",
                    body: "This is your cash and debt. Operating costs hit every month. If debt exceeds $25k, you lose."
                ),
                CoachmarkFrame(
                    anchor: .score, header: "YOUR SCORE",
                    body: "Score climbs when stores are empty. More empty stores = more points per month."
                ),
                CoachmarkFrame(
                    anchor: .threatMeter, header: "THREAT",
                    body: "This tracks how close you are to collapse. Keep it out of the red."
                )
            ]
        case .corridor:
            return [
                CoachmarkFrame(
                    anchor: .sceneVisitor, header: "VISITORS",
                    body: "Tap any visitor to see who they are and what they're thinking."
                ),
                CoachmarkFrame(
                    anchor: .sceneStore, header: "STORES",
                    body: "Tap a store to manage it — rent, evict, promo."
                )
            ]
        case .firstOffer:
            return [
                CoachmarkFrame(
                    anchor: nil, header: "A TENANT WANTS IN",
                    body: "Accepting fills a storefront (bad for score) but adds rent (good for survival). Declining keeps it empty. Your call."
                )
            ]
        case .pnl:
            return [
                CoachmarkFrame(
                    anchor: .pnlPanel, header: "MONTHLY P&L",
                    body: "Rent comes in. Operating costs, staff, and promo costs go out. Net is what you keep. Watch this panel every month."
                )
            ]
        case .watchList:
            return [
                CoachmarkFrame(
                    anchor: .watchList, header: "WATCH LIST",
                    body: "Problems live here. Hazards cost monthly fines. Decorations decay. Ignore at your own risk."
                )
            ]
        case .tabs:
            return [
                CoachmarkFrame(
                    anchor: .tabBar, header: "THE TABS",
                    body: "Operations manages staff and wings. Tenants shows who's paying rent. Promotions runs marketing. Revenue breaks down income. Mall is where the game lives."
                )
            ]
        case .scoreSources:
            return [
                CoachmarkFrame(
                    anchor: .scoreSources, header: "WHY YOU SCORED",
                    body: "This shows why your score ticked. Empty stores, sealed wings, and the life factor multiply together. Longer you survive, higher the multiplier."
                )
            ]
        case .graduation:
            return [
                CoachmarkFrame(
                    anchor: nil, header: "YEAR ONE · COMPLETE",
                    body: "You've survived year one. Time returns to full speed. The mall will start testing you. Good luck."
                )
            ]
        }
    }
}

// The overlay view. Reads vm.state.activeTutorialStep + the latest anchor
// dictionary from the parent and draws the appropriate frame.
struct CoachmarkOverlay: View {
    @Bindable var vm: GameViewModel
    let anchors: [CoachmarkAnchor: CGRect]

    // Index into the current step's frame list. Resets when the step changes.
    @State private var frameIndex: Int = 0
    @State private var lastStep: TutorialStep? = nil

    var body: some View {
        // Yield to decisions — spec: "if a tenant offer appears during a coachmark,
        // the coachmark yields to the decision." Exception: .firstOffer renders
        // OVER the tenant decision banner because its whole job is to frame it.
        if let step = vm.state.activeTutorialStep,
           vm.state.decision == nil || step.showsOverDecision {
            GeometryReader { geo in
                let frames = CoachmarkScript.frames(for: step)
                let clampedIndex = min(frameIndex, frames.count - 1)
                let frame = frames[clampedIndex]
                let isLast = clampedIndex >= frames.count - 1

                ZStack {
                    // Dim backdrop — absorbs taps so the player can't fight the tutorial.
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { }

                    // Highlight ring around the anchor if one was published.
                    if let anchorId = frame.anchor, let rect = anchors[anchorId] {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "#FAC775"), lineWidth: 3)
                            .frame(width: rect.width + 14, height: rect.height + 14)
                            .position(x: rect.midX, y: rect.midY)
                            .shadow(color: Color(hex: "#FAC775").opacity(0.6), radius: 8)
                    }

                    // Card — anchored near the target, or centered if no anchor /
                    // anchor rect not yet published.
                    card(frame: frame,
                         pageLabel: frames.count > 1 ? "\(clampedIndex + 1) of \(frames.count)" : nil,
                         buttonTitle: isLast ? "Got It" : "Next",
                         action: { advance(frames: frames, isLast: isLast) })
                        .frame(maxWidth: 380)
                        .position(cardPosition(container: geo.size,
                                               target: frame.anchor.flatMap { anchors[$0] },
                                               avoidTopBand: vm.state.decision != nil))
                }
                .onAppear { syncIndex(for: step) }
                .onChange(of: vm.state.activeTutorialStep) { _, new in
                    if let s = new { syncIndex(for: s) }
                }
            }
            .transition(.opacity)
        }
    }

    // Card: header, body text, page indicator, button.
    private func card(frame: CoachmarkFrame,
                      pageLabel: String?,
                      buttonTitle: String,
                      action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let header = frame.header {
                Text(header)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color(hex: "#c4919a"))
            }
            Text(frame.body)
                .font(.system(size: 17, design: .serif))
                .foregroundStyle(Color(hex: "#f4e4b0"))
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if let pageLabel {
                    Text(pageLabel)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(Color(hex: "#888780"))
                }
                Spacer()
                Button(buttonTitle, action: action)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: "#2a0a15"))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Color(hex: "#c4919a"))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#8a4a5a"), lineWidth: 2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(hex: "#1a1917"))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: "#FAC775"), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.7), radius: 12, y: 4)
    }

    // Place the card below the target if the target is in the top half, else above.
    // If there's no target, center the card — but shift down when a decision
    // banner is occupying the top band (e.g. during .firstOffer).
    private func cardPosition(container: CGSize, target: CGRect?, avoidTopBand: Bool) -> CGPoint {
        guard let t = target else {
            let y = avoidTopBand ? container.height * 0.62 : container.height / 2
            return CGPoint(x: container.width / 2, y: y)
        }
        let margin: CGFloat = 20
        let cardHalfHeight: CGFloat = 80   // approximation; card auto-sizes vertically
        let x = min(max(t.midX, 200), container.width - 200)
        let belowY = t.maxY + cardHalfHeight + margin
        let aboveY = t.minY - cardHalfHeight - margin
        let y = (t.midY < container.height / 2) ? belowY : aboveY
        return CGPoint(x: x, y: y)
    }

    private func syncIndex(for step: TutorialStep) {
        if lastStep != step {
            frameIndex = 0
            lastStep = step
        }
    }

    private func advance(frames: [CoachmarkFrame], isLast: Bool) {
        if isLast {
            vm.dismissCoachmark()
            frameIndex = 0
        } else {
            frameIndex += 1
        }
    }
}
