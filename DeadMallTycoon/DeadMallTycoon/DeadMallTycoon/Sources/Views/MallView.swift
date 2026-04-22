import SwiftUI

// The living mall scene. Phase A UI overhaul removed the three persistent
// side panels (P&L, status/watch-list, selected/thoughts-log) so the scene
// can be the hero of the screen, per tycoon-game convention.
//
// Phase C additions:
// - Info cards (store / decoration) render as overlays inside this view and
//   pin next to the tapped node via scene→SwiftUI coord conversion.
// - The `.watchList` coachmark anchor moved here from the threat meter because
//   the watch-list info is now ambient on the scene (hazard/closing dots,
//   wing tints).
struct MallView: View {
    @Bindable var vm: GameViewModel

    // SKView-local anchor points for the currently-selected store / decoration.
    // Published by MallScene whenever selection or view size changes.
    @State private var storeAnchor: CGPoint?
    @State private var decorationAnchor: CGPoint?

    var body: some View {
        ZStack {
            MallSceneView(
                vm: vm,
                onStoreAnchorChange: { storeAnchor = $0 },
                onDecorationAnchorChange: { decorationAnchor = $0 }
            )
            .background(Color(hex: "#0a0a0e"))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .aspectRatio(
                GameConstants.worldWidth / GameConstants.worldHeight,
                contentMode: .fit
            )
            .overlay {
                GeometryReader { geo in
                    infoCardOverlay(in: geo.size)
                }
            }
            .coachmarkAnchor(.sceneVisitor)
            .coachmarkAnchor(.sceneStore)
            .coachmarkAnchor(.watchList)   // Phase C — warnings are ambient on the scene now

            // Placement mode banner — v9 Prompt 3: now sourced from
            // placingArtifactType + ArtifactCatalog.info(type).name.
            if let type = vm.state.placingArtifactType {
                VStack {
                    Button(action: { vm.cancelPlacement() }) {
                        Text("Placing \(ArtifactCatalog.info(type).name) · Tap corridor · Tap here to cancel")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Color(hex: "#7fd3f0").opacity(0.95))
                            .foregroundStyle(Color(hex: "#2a2a34"))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    Spacer()
                }
            }

            // v9 Prompt 4 Phase 6 — visitor profile panel. Pinned to the
            // bottom of this ZStack (which extends into the aspect-fit
            // letterbox space below the mall scene). Overlay only; the
            // mall scene's size and on-screen position are unchanged when
            // the panel appears or dismisses.
            VStack {
                Spacer()
                VisitorProfilePanel(vm: vm)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            .allowsHitTesting(vm.state.selectedVisitorIdentity != nil)

            // v9 Prompt 6 — closure event card. Silent-queue overlay; the
            // front event in state.pendingClosureEvents renders while the
            // rest wait. No pause — time continues underneath. Obeys the
            // Phase 0 overlay-only invariant: the mall scene's size and
            // position do not shift when this card appears or dismisses.
            if let frontClosure = vm.state.pendingClosureEvents.first {
                ClosureEventCard(vm: vm, event: frontClosure)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Info card overlay (positioned relative to the scene viewport)

    @ViewBuilder
    private func infoCardOverlay(in viewportSize: CGSize) -> some View {
        if let id = vm.state.selectedStoreId, let pt = storeAnchor {
            StoreInfoCard(vm: vm, storeId: id)
                .frame(maxWidth: 360)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { cardGeo in
                        Color.clear.preference(
                            key: CardSizeKey.self,
                            value: cardGeo.size
                        )
                    }
                )
                .modifier(CardPositionModifier(anchor: pt, viewport: viewportSize))
        } else if let id = vm.state.selectedDecorationId, let pt = decorationAnchor {
            // v9 Prompt 3 — DecorationInfoCard → ArtifactInfoCard.
            ArtifactInfoCard(vm: vm, artifactId: id)
                .frame(maxWidth: 360)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(CardPositionModifier(anchor: pt, viewport: viewportSize))
        }
    }
}

// Positions an info card adjacent to an anchor point, clamped to the viewport.
// Prefers to render above the anchor; falls back below if it would clip off the
// top edge. Horizontal position is centered on the anchor, clamped to the edges.
private struct CardPositionModifier: ViewModifier {
    let anchor: CGPoint
    let viewport: CGSize

    // Reasonable estimate for store/decoration card heights. Exact positioning
    // needs the card's own measured size, but a conservative estimate keeps the
    // card on-screen without adding a second layout pass.
    private let estimatedCardHeight: CGFloat = 260
    private let estimatedCardWidth: CGFloat = 360
    private let gap: CGFloat = 20

    func body(content: Content) -> some View {
        let halfH = estimatedCardHeight / 2
        let halfW = estimatedCardWidth / 2

        // Prefer above the anchor; if it would clip off the top, go below.
        let preferredY = anchor.y - gap - halfH
        let fallbackY = anchor.y + gap + halfH
        let needsBelow = preferredY - halfH < 0
        let rawY = needsBelow ? fallbackY : preferredY

        let clampedX = max(halfW + 8, min(viewport.width - halfW - 8, anchor.x))
        let clampedY = max(halfH + 8, min(viewport.height - halfH - 8, rawY))

        return content
            .position(x: clampedX, y: clampedY)
    }
}

private struct CardSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
