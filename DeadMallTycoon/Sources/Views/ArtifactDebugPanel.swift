// v9: DIAGNOSTIC — #if DEBUG wrapper temporarily removed (Prompt 1 diagnosis).
// Restore the wrapper once we confirm whether the macro is the reason the DBG
// pill wasn't visible in DeadMallTycoonApp.swift.
import SwiftUI

// v9: Read-only dev panel. Lists every Artifact in GameState so Prompts 2+ can
// be visually verified as they wire creation/decay/accumulation. Not shipped.
struct ArtifactDebugPanel: View {
    @Bindable var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#3a3a48"))
            if vm.state.artifacts.isEmpty {
                empty
            } else {
                list
            }
        }
        .background(Color(hex: "#14141a"))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text("ARTIFACTS · DEBUG")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(hex: "#b8e8f8"))
            Spacer()
            Text("\(vm.state.artifacts.count)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#6a6a78"))
            Button("Close") { dismiss() }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#6a6a78"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("No artifacts yet.")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(Color(hex: "#6a6a78"))
            Text("Prompt 1 adds the model only. Later prompts wire creation.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(hex: "#4a4a58"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(vm.state.artifacts) { artifact in
                    row(artifact)
                }
            }
            .padding(16)
        }
    }

    private func row(_ a: Artifact) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(a.name.isEmpty ? "(unnamed)" : a.name)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#e8e8f0"))
                Spacer()
                Text("#\(a.id)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(hex: "#4a4a58"))
            }
            Text(a.type.rawValue)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(hex: "#ff4dbd"))
            HStack(spacing: 12) {
                label("YEAR", String(a.yearCreated))
                label("COND", "\(a.condition)/4")
                label("WEIGHT", String(format: "%.2f", a.memoryWeight))
            }
            Text(originText(a.origin))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(hex: "#9090a0"))
            Text("triggers: \(a.thoughtTriggers.count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(hex: "#6a6a78"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(hex: "#1a1a24"))
        .overlay(
            Rectangle()
                .frame(width: 2)
                .foregroundStyle(Color(hex: "#3a3a48")),
            alignment: .leading
        )
    }

    private func label(_ k: String, _ v: String) -> some View {
        HStack(spacing: 4) {
            Text(k)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#6a6a78"))
            Text(v)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Color(hex: "#e8e8f0"))
        }
    }

    private func originText(_ origin: ArtifactOrigin) -> String {
        switch origin {
        case .tenant(let name):       return "origin: tenant · \(name)"
        case .event(let name):        return "origin: event · \(name)"
        case .playerAction(let name): return "origin: player · \(name)"
        }
    }
}
// v9: DIAGNOSTIC — trailing #endif removed to match ungated top of file.
