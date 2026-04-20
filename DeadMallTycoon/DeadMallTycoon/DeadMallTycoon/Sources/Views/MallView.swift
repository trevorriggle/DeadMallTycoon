import SwiftUI

// The living mall scene. Phase A UI overhaul removed the three persistent
// side panels (P&L, status/watch-list, selected/thoughts-log) so the scene
// can be the hero of the screen, per tycoon-game convention.
//
// All scene chrome (date, cash, threat, speed, manage) is now edge-anchored
// in ContentView. Tapped-store / tapped-decoration cards float in on demand.
// Visitor thoughts remain in-scene via MallScene.showThoughtAboveVisitor.
//
// The `.aspectRatio(worldW/worldH, .fit)` modifier is the critical piece —
// it guarantees all 20 storefronts are visible at every orientation and form
// factor (iPad/iPhone · landscape/portrait · split-screen), letterboxed onto
// the dark game background rather than clipped.
struct MallView: View {
    @Bindable var vm: GameViewModel

    var body: some View {
        ZStack {
            MallSceneView(vm: vm)
                .background(Color(hex: "#0a0908"))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .aspectRatio(
                    GameConstants.worldWidth / GameConstants.worldHeight,
                    contentMode: .fit
                )
                .coachmarkAnchor(.sceneVisitor)
                .coachmarkAnchor(.sceneStore)

            // Placement mode banner — stays as in Phase 1-5 so players can
            // cancel an in-flight decoration placement.
            if let kind = vm.state.placingDecoration {
                VStack {
                    Button(action: { vm.cancelPlacement() }) {
                        Text("Placing \(DecorationTypes.type(kind).name) · Tap corridor · Tap here to cancel")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Color(hex: "#FAC775").opacity(0.95))
                            .foregroundStyle(Color(hex: "#2a1a0a"))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    Spacer()
                }
            }
        }
    }
}
