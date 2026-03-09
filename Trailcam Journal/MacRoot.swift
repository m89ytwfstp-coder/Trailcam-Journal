
//
//  MacRoot.swift
//  Trailcam Journal
//

#if os(macOS)
import SwiftUI

struct ContentViewMac: View {

    enum SidebarSection: String, CaseIterable, Identifiable {
        case importQueue = "Import"
        case entries     = "Entries"
        case map         = "Map"
        case stats       = "Stats"
        case bucketList  = "Bucket List"
        case rankings    = "Rankings"
        case more        = "Settings"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .importQueue: "square.and.arrow.down"
            case .entries:     "list.bullet"
            case .map:         "map"
            case .stats:       "chart.bar"
            case .bucketList:  "checklist"
            case .rankings:    "trophy"
            case .more:        "gearshape"
            }
        }
    }

    @EnvironmentObject var store: EntryStore

    @State private var selection: SidebarSection? = .importQueue

    private var draftCount: Int { store.entries.filter { $0.isDraft }.count }
    private var entryCount: Int { store.entries.filter { !$0.isDraft }.count }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                // ── Journal ──────────────────────────────────────────
                Section("Journal") {
                    sidebarRow(.importQueue, badge: draftCount > 0 ? draftCount : nil)
                    sidebarRow(.entries,     badge: entryCount > 0 ? entryCount : nil)
                    sidebarRow(.map)
                }

                // ── Insights ─────────────────────────────────────────
                Section("Insights") {
                    sidebarRow(.stats)
                    sidebarRow(.bucketList)
                    sidebarRow(.rankings)
                }

                // ── System ───────────────────────────────────────────
                Section {
                    sidebarRow(.more)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Trailcam Journal")
            .navigationSplitViewColumnWidth(min: 185, ideal: 210, max: 240)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(AppColors.primary)
    }

    // MARK: - Sidebar row

    @ViewBuilder
    private func sidebarRow(_ section: SidebarSection, badge: Int? = nil) -> some View {
        HStack(spacing: 6) {
            Label(section.rawValue, systemImage: section.symbol)
            if let count = badge {
                Spacer()
                Text("\(count)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.6))
                    .clipShape(Capsule())
            }
        }
        .tag(section)
    }

    // MARK: - Detail routing

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .importQueue {
        case .importQueue: MacImportPane()
        case .entries:     MacEntriesPane()
        case .map:         MacMapPane()
        case .stats:       StatsView()
        case .bucketList:  BucketListTabView()
        case .rankings:    MacRankingsPane()
        case .more:        SettingsView()
        }
    }
}

// ── Rankings pane ─────────────────────────────────────────────────────────────

struct MacRankingsPane: View {
    @EnvironmentObject var store: EntryStore

    private var finalEntries: [TrailEntry] { store.entries.filter { !$0.isDraft } }

    var body: some View {
        TabView {
            SpeciesRankingView(entries: finalEntries)
                .tabItem { Label("Species", systemImage: "pawprint") }
            CameraRankingView(entries: finalEntries)
                .tabItem { Label("Cameras", systemImage: "camera") }
        }
        .appScreenBackground()
        .navigationTitle("Rankings")
    }
}
#endif
