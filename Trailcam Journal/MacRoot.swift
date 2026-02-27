import SwiftUI

#if os(macOS)
struct ContentViewMac: View {
    enum SidebarSection: String, CaseIterable, Identifiable {
        case importQueue = "Import"
        case entries = "Entries"
        case map = "Map"
        case stats = "Stats"
        case more = "More"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .importQueue: return "square.and.arrow.down"
            case .entries: return "list.bullet"
            case .map: return "map"
            case .stats: return "chart.bar"
            case .more: return "ellipsis"
            }
        }
    }

    @State private var selection: SidebarSection? = .importQueue

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationTitle("Trailcam Journal")
            .listStyle(.sidebar)
        } detail: {
            VStack(spacing: 10) {
                Text(selection?.rawValue ?? "Trailcam Journal")
                    .font(.title2.weight(.semibold))
                Text("Native macOS shell is ready. Feature views can be wired incrementally.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
#endif
