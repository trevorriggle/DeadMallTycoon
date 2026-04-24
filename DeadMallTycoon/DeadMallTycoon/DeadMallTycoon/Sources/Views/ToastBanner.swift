import SwiftUI

// v9 — auto-dismiss toast banner. Renders one Toast; uses .task to
// schedule its own dismissal via vm.dismissToast(id:) after the toast's
// duration. Fade-in (0.25s) and fade-out (0.5s) handled by transitions
// on the parent stack.
//
// Style-driven appearance — closures get retailer-name typography, info
// is small/neutral, victory has a green accent, loss has a magenta accent.
struct ToastBanner: View {
    @Bindable var vm: GameViewModel
    let toast: Toast

    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(toast.title)
                .font(titleFont)
                .tracking(0.4)
                .foregroundStyle(titleColor)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            if let subtitle = toast.subtitle {
                Text(subtitle)
                    .font(.system(size: 13, design: .default))
                    .italic()
                    .foregroundStyle(Color(hex: "#d8d8e0"))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .background(Color(hex: "#14141a").opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(borderColor, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
        .opacity(visible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { visible = true }
        }
        .task {
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            withAnimation(.easeIn(duration: 0.5)) { visible = false }
            // Hold during the fade-out before removing from state so the
            // animation can play to completion.
            try? await Task.sleep(nanoseconds: 500_000_000)
            vm.dismissToast(id: toast.id)
        }
    }

    private var titleFont: Font {
        switch toast.style {
        case .closure: return .system(size: 16, weight: .black, design: .default)
        default:       return .system(size: 13, weight: .bold, design: .monospaced)
        }
    }

    private var titleColor: Color {
        switch toast.style {
        case .info:    return Color(hex: "#d8d8e0")
        case .closure: return Color(hex: "#b8e8f8")
        case .victory: return Color(hex: "#5DCAA5")
        case .loss:    return Color(hex: "#ff4dbd")
        }
    }

    private var borderColor: Color {
        switch toast.style {
        case .info:    return Color(hex: "#3a3a48")
        case .closure: return Color(hex: "#8a2a6a")
        case .victory: return Color(hex: "#2a8a70")
        case .loss:    return Color(hex: "#5a2a4a")
        }
    }

    private var maxWidth: CGFloat {
        switch toast.style {
        case .closure: return 460
        default:       return 340
        }
    }
}

// Stack container — vertically lays out the queue with light spacing.
// Newest toasts append to the top so a fast cascade reads chronologically.
struct ToastStack: View {
    @Bindable var vm: GameViewModel

    var body: some View {
        VStack(spacing: 6) {
            ForEach(vm.state.toasts) { t in
                ToastBanner(vm: vm, toast: t)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: vm.state.toasts.map(\.id))
    }
}
