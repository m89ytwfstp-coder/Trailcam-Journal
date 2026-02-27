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
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .importQueue {
        case .importQueue:
            MacImportPane()
        case .entries:
            MacEntriesPane()
        case .map:
            placeholder(title: "Map", subtitle: "Map view is currently iOS-only.")
        case .stats:
            placeholder(title: "Stats", subtitle: "Stats will be added after shared chart/mac guards are complete.")
        case .more:
            placeholder(title: "More", subtitle: "Settings and utilities will be exposed here.")
        }
    }

    private func placeholder(title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
