import SwiftUI

@main
struct DeadMallTycoonApp: App {
    @State private var vm = GameViewModel()

    init() {
        // v9 — configure AVAudioSession before any player loads so music
        // and ambient hum aren't silenced by the hardware silent switch.
        AudioSession.configure()
    }

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
    @State private var showManage = false
    @State private var showPnL = false
    // v9 Prompt 3 followup — top-level Acquire shortcut.
    @State private var showAcquire = false
    // v9 Prompt 19 — top-level Seal shortcut.
    @State private var showSealing = false
    @Environment(\.horizontalSizeClass) private var hSize
    #if DEBUG
    // v9: Artifact debug panel entry — Prompt 1. Dev-only, stripped from release.
    @State private var showArtifactDebug = false
    #endif

    var body: some View {
        ZStack {
            Color(hex: "#0a0a0e").ignoresSafeArea()
            if !vm.state.started {
                StartScreenView(onStart: { tutorialEnabled in
                    vm.startGame(tutorialEnabled: tutorialEnabled)
                })
            } else {
                gameBody
                if vm.state.gameover {
                    GameOverView(vm: vm)
                        .transition(.opacity)
                }
            }
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
            // v9 Prompt 4 Phase 0 — HUD layout lock.
            // The core VStack is HUD + MallView only. DecisionBanner used to
            // sit as a sibling in this VStack, which forced MallView (maxHeight
            // infinity) to compress whenever a decision appeared. That
            // displacement broke the mall scene's stable-ground feel — it's
            // the emotional center of the game and must not move when a pop-up
            // fires. The banner is now a ZStack overlay below (positioned with
            // alignment), rendered above the mall without affecting layout.
            // The mall scene's on-screen position is invariant with respect
            // to decision presentation; any future pop-up must follow the
            // same overlay-not-insertion pattern.
            VStack(spacing: 6) {
                HUDView(vm: vm, onTapCash: { showPnL = true })
                MallView(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            // v9 Prompt 4 Phase 0 — decision banner overlay.
            // Regular width: pins near the top, just below the HUD band.
            // Compact width: pins near the bottom, just above the button row.
            // Either way: overlay, never a VStack child. The mall scene does
            // not shrink when this appears.
            if let decision = vm.state.decision {
                VStack(spacing: 0) {
                    if hSize != .compact {
                        DecisionBanner(vm: vm, decision: decision)
                            .padding(.top, 52)   // clear the HUD band
                            .padding(.horizontal, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    } else {
                        Spacer()
                        DecisionBanner(vm: vm, decision: decision)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 72) // clear the button row
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .zIndex(50)
                .allowsHitTesting(true)
            }

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
                        // v9 Prompt 19 — SEAL between ACQUIRE and MANAGE so
                        // the sealing surface is discoverable at the same
                        // level as the other top-level action shortcuts.
                        SealButton(action: { showSealing = true })
                        ManageButton(action: { showManage = true })
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
        .sheet(isPresented: $showSealing) { SealingSheet(vm: vm) }
        #if DEBUG
        .sheet(isPresented: $showArtifactDebug) { ArtifactDebugPanel(vm: vm) }
        #endif
    }
}
