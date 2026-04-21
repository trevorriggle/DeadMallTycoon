import SwiftUI

@main
struct DeadMallTycoonApp: App {
    @State private var vm = GameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                .preferredColorScheme(.dark)
        }
    }
}

// Root. Handles three top-level states: start screen, live game, game-over.
// Phase A/B/C UI overhaul: tycoon-convention scene-first layout. The mall scene
// fills the viewport; the only persistent chrome is a thin top strip and two
// bottom-corner controls (MANAGE + speed). Everything else is reveal-on-demand.
//
// Phase C — decision banner responsive placement: on compact-width layouts the
// banner docks at the bottom of the screen and the mall compresses up to make
// room; on regular widths it stays above the mall. Either way, it never
// overlays the mall scene.
struct ContentView: View {
    @Bindable var vm: GameViewModel
    @State private var showingTutorial = false
    @State private var showManage = false
    @State private var showPnL = false
    @State private var coachmarkAnchors: [CoachmarkAnchor: CGRect] = [:]
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        ZStack {
            Color(hex: "#0a0a0e").ignoresSafeArea()
            if !vm.state.started {
                StartScreenView(onStart: { withTutorial in
                    vm.startGame(withTutorial: withTutorial)
                })
            } else {
                gameBody
                if vm.state.gameover {
                    GameOverView(vm: vm)
                        .transition(.opacity)
                }
                CoachmarkOverlay(vm: vm, anchors: coachmarkAnchors)
            }
        }
        .coordinateSpace(name: CoachmarkSpace.name)
        .onPreferenceChange(CoachmarkAnchorKey.self) { coachmarkAnchors = $0 }
        .sheet(isPresented: $showingTutorial) {
            TutorialView(onClose: { showingTutorial = false })
        }
    }

    // Layout:
    //   Regular width (iPad)     : [HUD · Banner? · Mall]  — banner above mall
    //   Compact width (iPhone)   : [HUD · Mall · Banner?]  — banner below mall
    // In both, the floating MANAGE button + Speed controls overlay the bottom
    // corners. Info cards (store / decoration) render inside MallView itself
    // so they can pin near the tapped scene node.
    private var gameBody: some View {
        ZStack {
            VStack(spacing: 6) {
                HUDView(vm: vm, onTapCash: { showPnL = true })

                if hSize != .compact, let decision = vm.state.decision {
                    DecisionBanner(vm: vm, decision: decision)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                MallView(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if hSize == .compact, let decision = vm.state.decision {
                    DecisionBanner(vm: vm, decision: decision)
                        .frame(maxWidth: .infinity)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            // Bottom-left: MANAGE drawer trigger.
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    ManageButton(action: { showManage = true })
                        .coachmarkAnchor(.tabBar)   // rebound — MANAGE replaces the old TabBar
                    Spacer()
                    SpeedControls(vm: vm)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showManage) { ManageDrawer(vm: vm) }
        .sheet(isPresented: $showPnL)    { PnLModal(vm: vm) }
    }
}
