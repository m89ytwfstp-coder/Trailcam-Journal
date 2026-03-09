import SwiftUI

#if os(macOS)
struct ContentViewMac: View {
    enum SidebarSection: String, CaseIterable, Identifiable {
        case importQueue = "Import"
        case entries = "Entries"
        case map = "Map"
        case stats = "Stats"
        case bucketList = "Bucket List"
        case rankings = "Rankings"
        case more = "Settings"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .importQueue: return "square.and.arrow.down"
            case .entries: return "list.bullet"
            case .map: return "map"
            case .stats: return "chart.bar"
            case .bucketList: return "checklist"
            case .rankings: return "trophy"
            case .more: return "gearshape"
            }
        }
    }

    @EnvironmentObject var store: EntryStore

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
            MacMapPane()
        case .stats:
            StatsView()
        case .bucketList:
            BucketListTabView()
        case .rankings:
            MacRankingsPane()
        case .more:
            SettingsView()
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

// MARK: - Rankings pane (Species + Camera tabs)

struct MacRankingsPane: View {
    @EnvironmentObject var store: EntryStore

    private var finalEntries: [TrailEntry] {
        store.entries.filter { !$0.isDraft }
    }

    var body: some View {
        TabView {
            SpeciesRankingView(entries: finalEntries)
                .tabItem { Label("Species", systemImage: "pawprint") }
            CameraRankingView(entries: finalEntries)
                .tabItem { Label("Cameras", systemImage: "camera") }
        }
        .appScreenBackground()
    }
}
#endif
