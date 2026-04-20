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
struct ContentView: View {
    @Bindable var vm: GameViewModel
    @State private var showingTutorial = false

    var body: some View {
        ZStack {
            Color(hex: "#0a0908").ignoresSafeArea()
            if !vm.state.started {
                StartScreenView(onStart: { vm.startGame() })
            } else {
                gameBody
                if vm.state.gameover {
                    GameOverView(vm: vm)
                        .transition(.opacity)
                }
            }
        }
        .sheet(isPresented: $showingTutorial) {
            TutorialView(onClose: { showingTutorial = false })
        }
    }

    private var gameBody: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 6) {
                goalStrip
                HUDView(vm: vm)
                TabBar(current: vm.state.currentTab, onSelect: { vm.switchTab($0) })
                // MallView is always in the tree so the SpriteKit scene is not torn down
                // when the player switches tabs. Non-Mall tabs overlay on top of it.
                ZStack {
                    MallView(vm: vm)
                        .opacity(vm.state.currentTab == .mall ? 1 : 0)
                        .allowsHitTesting(vm.state.currentTab == .mall)
                    if vm.state.currentTab != .mall {
                        OpsTabsView(vm: vm, tab: vm.state.currentTab)
                    }
                }
            }
            .padding(12)

            // Decision banner floats above all tabs so the paused state is always visible,
            // not just when the Mall tab is active.
            if let decision = vm.state.decision {
                DecisionBanner(vm: vm, decision: decision)
                    .padding(.top, 120)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var goalStrip: some View {
        HStack(spacing: 12) {
            Text("GOAL")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#c4919a"))
            Text("Keep the mall ")
                .foregroundStyle(Color(hex: "#c4b4a0"))
            + Text("barely open")
                .foregroundStyle(Color(hex: "#FAC775"))
                .fontWeight(.bold)
            + Text(" as long as possible. Empty spaces score. Tenants pay the bills. Find the edge.")
                .foregroundStyle(Color(hex: "#c4b4a0"))
            Spacer()
            Button("How to Play") { showingTutorial = true }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color(hex: "#c4919a"))
                .padding(.horizontal, 10).padding(.vertical, 3)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(hex: "#5a2a35")))
        }
        .font(.system(size: 15, design: .serif))
        .italic()
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(
            LinearGradient(colors: [Color(hex: "#2a1515"), Color(hex: "#1a1410"), Color(hex: "#2a1515")],
                           startPoint: .leading, endPoint: .trailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: "#5a2a35")))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct TabBar: View {
    let current: Tab
    let onSelect: (Tab) -> Void

    private let tabs: [(Tab, String)] = [
        (.mall, "Mall"),
        (.operations, "Operations"),
        (.tenants, "Tenants"),
        (.promotions, "Promotions"),
        (.revenue, "Revenue"),
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.0) { pair in
                let (tab, name) = pair
                let on = tab == current
                Button(action: { onSelect(tab) }) {
                    Text(name.uppercased())
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .foregroundStyle(on ? Color(hex: "#FAC775") : Color(hex: "#888780"))
                        .background(on ? Color(hex: "#2a2520") : Color(hex: "#1a1917"))
                        .overlay(
                            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 6, topTrailing: 6))
                                .strokeBorder(on ? Color(hex: "#5a4a3a") : Color(hex: "#3a3935"))
                        )
                        .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 6, topTrailing: 6)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}
