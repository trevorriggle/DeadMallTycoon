import SwiftUI

@main
struct DeadMallTycoonApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("Dead Mall Tycoon")
            .font(.system(.title, design: .monospaced))
    }
}
