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
// Phase A UI overhaul: tycoon-convention scene-first layout. The mall scene
// fills the viewport; the only persistent chrome is a thin top strip and two
// bottom-corner controls (MANAGE + speed). Everything else is reveal-on-demand.
struct ContentView: View {
    @Bindable var vm: GameViewModel
    @State private var showingTutorial = false
    @State private var showManage = false
    @State private var showPnL = false
    // Collected from .coachmarkAnchor(...) modifiers throughout the game body.
    @State private var coachmarkAnchors: [CoachmarkAnchor: CGRect] = [:]

    var body: some View {
        ZStack {
            Color(hex: "#0a0908").ignoresSafeArea()
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
                // Overlay sits above the game but below the game-over card.
                CoachmarkOverlay(vm: vm, anchors: coachmarkAnchors)
            }
        }
        .coordinateSpace(name: CoachmarkSpace.name)
        .onPreferenceChange(CoachmarkAnchorKey.self) { coachmarkAnchors = $0 }
        .sheet(isPresented: $showingTutorial) {
            TutorialView(onClose: { showingTutorial = false })
        }
    }

    // Scene-first layout. Vertical stack:
    //   1. Thin top strip (date/month · cash · threat)
    //   2. Decision banner (if any) — above the mall so it never covers it
    //   3. Mall scene, takes all remaining space, letterboxed to world aspect
    // Floating overlays (MANAGE button bottom-left, speed controls bottom-right,
    // store/decoration info cards) sit above the scene without occupying layout space.
    private var gameBody: some View {
        ZStack {
            VStack(spacing: 6) {
                HUDView(vm: vm, onTapCash: { showPnL = true })

                if let decision = vm.state.decision {
                    DecisionBanner(vm: vm, decision: decision)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                MallView(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            // Store / decoration info cards — tap-to-reveal. Positioned at bottom-center
            // as a Phase A stub; Phase B pins them near the tapped scene node via
            // scene→screen coordinate conversion.
            if let id = vm.state.selectedStoreId {
                VStack {
                    Spacer()
                    StoreInfoCard(vm: vm, storeId: id)
                        .padding(.bottom, 60)   // clear the bottom-corner controls
                }
                .transition(.scale.combined(with: .opacity))
            } else if let id = vm.state.selectedDecorationId {
                VStack {
                    Spacer()
                    DecorationInfoCard(vm: vm, decorationId: id)
                        .padding(.bottom, 60)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showManage) { ManageDrawer(vm: vm) }
        .sheet(isPresented: $showPnL)    { PnLModal(vm: vm) }
    }
}
