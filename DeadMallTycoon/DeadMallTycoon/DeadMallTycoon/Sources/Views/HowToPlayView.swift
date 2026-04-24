import SwiftUI

// v9 Prompt 18 Phase B — How to Play reference.
//
// Scrollable reader presented as a sheet. Invoked from the start
// screen (before a run begins) and from the MANAGE drawer footer
// (mid-run, for reference). Content sourced from HowToPlayContent.
// No navigation between sections — top-to-bottom scroll, because
// the expected pattern is "open, find the thing, read, close."
struct HowToPlayView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#3a3a48"))
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(HowToPlayContent.sections) { section in
                        sectionView(section)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0a0a0e"))
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("HOW TO PLAY")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color(hex: "#ff4dbd"))
                Text("THE CONTROLLED DECLINE")
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(2.4)
                    .foregroundStyle(Color(hex: "#6a6a78"))
            }
            Spacer()
            Button(action: onClose) {
                Text("Close")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: "#2a0a2a"))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color(hex: "#7fd3f0"))
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color(hex: "#2a6a8a"), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(hex: "#14141a"))
    }

    private func sectionView(_ section: HowToPlaySection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title.uppercased())
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color(hex: "#7fd3f0"))
            Text(section.body)
                .font(.system(size: 16, design: .default))
                .foregroundStyle(Color(hex: "#d8d8e0"))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
