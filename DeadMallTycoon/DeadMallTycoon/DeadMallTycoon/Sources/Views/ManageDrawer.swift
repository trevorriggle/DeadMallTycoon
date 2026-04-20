import SwiftUI

// Bottom-drawer management sheet. Six tabs: Tenants · Promos · Staff · Wings · Ads · Build.
// Phase A stub — headers + "TK" bodies. Phase B lifts content from the old
// OpsTabsView.swift and MallView side panels into these tab bodies.
struct ManageDrawer: View {
    @Bindable var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tab: ManageTab = .tenants

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider().background(Color(hex: "#3a3935"))
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(stubCopy(for: tab))
                        .font(.system(size: 15, design: .serif))
                        .italic()
                        .foregroundStyle(Color(hex: "#888780"))
                    Text("— Phase B —")
                        .font(.system(size: 11, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(Color(hex: "#5a4a3a"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .background(Color(hex: "#1a1917"))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text("MANAGE")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(hex: "#f4e4b0"))
            Spacer()
            Button("Close") { dismiss() }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#888780"))
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ManageTab.allCases, id: \.self) { t in
                    Button(action: { tab = t }) {
                        Text(t.title.uppercased())
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundStyle(t == tab ? Color(hex: "#FAC775") : Color(hex: "#888780"))
                            .background(t == tab ? Color(hex: "#2a2520") : Color.clear)
                            .overlay(
                                Rectangle().frame(height: 2)
                                    .foregroundStyle(t == tab ? Color(hex: "#FAC775") : Color.clear),
                                alignment: .bottom
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private func stubCopy(for t: ManageTab) -> String {
        switch t {
        case .tenants:     return "Active tenants, rent adjust, force-evict, and approach prospective tenants."
        case .promos:      return "Launch temporary promos. Every one trades something for something."
        case .staff:       return "Security, janitorial, maintenance, marketing. Monthly retainers."
        case .wings:       return "Seal or downgrade wings. Sealing nets score but loses tenants."
        case .ads:         return "Sponsor deals — passive income at an aesthetic cost."
        case .build:       return "Place decorations. Kugel, fountain, plant, neon, bench, directory."
        }
    }
}

enum ManageTab: String, CaseIterable, Hashable {
    case tenants, promos, staff, wings, ads, build
    var title: String {
        switch self {
        case .tenants: return "Tenants"
        case .promos:  return "Promos"
        case .staff:   return "Staff"
        case .wings:   return "Wings"
        case .ads:     return "Ads"
        case .build:   return "Build"
        }
    }
}
