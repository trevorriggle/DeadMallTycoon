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
    // v9 Prompt 3 followup — top-level Acquire shortcut.
    @State private var showAcquire = false
    @State private var coachmarkAnchors: [CoachmarkAnchor: CGRect] = [:]
    @Environment(\.horizontalSizeClass) private var hSize
    #if DEBUG
    // v9: Artifact debug panel entry — Prompt 1. Dev-only, stripped from release.
    @State private var showArtifactDebug = false
    #endif

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

            // Bottom-left: ACQUIRE shortcut stacked above MANAGE drawer trigger.
            // v9 Prompt 3 followup — Acquire promoted to the HUD as a
            // top-level shortcut. MANAGE is unchanged; the Acquire tab inside
            // MANAGE is also untouched (this is an additional entry point,
            // not a replacement).
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        AcquireButton(action: { showAcquire = true })
                        ManageButton(action: { showManage = true })
                            .coachmarkAnchor(.tabBar)   // rebound — MANAGE replaces the old TabBar
                    }
                    #if DEBUG
                    // v9: Dev-only button to inspect the Artifact list. Sits next to
                    // MANAGE; stripped from release builds by the surrounding #if DEBUG.
                    Button(action: { showArtifactDebug = true }) {
                        Text("DBG")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(Color(hex: "#b8e8f8"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#14141a").opacity(0.8))
                            .overlay(
                                Rectangle().stroke(Color(hex: "#3a3a48"), lineWidth: 1)
                            )
                    }
                    .padding(.leading, 6)
                    #endif
                    Spacer()
                    SpeedControls(vm: vm)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showManage)  { ManageDrawer(vm: vm) }
        .sheet(isPresented: $showPnL)     { PnLModal(vm: vm) }
        .sheet(isPresented: $showAcquire) { ArtifactAcquireSheet(vm: vm) }
        #if DEBUG
        .sheet(isPresented: $showArtifactDebug) { ArtifactDebugPanel(vm: vm) }
        #endif
    }
}
