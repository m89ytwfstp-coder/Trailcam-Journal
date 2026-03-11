
//
//  MacRoot.swift
//  Trailcam Journal
//

#if os(macOS)
import SwiftUI

struct ContentViewMac: View {

    // ── Sidebar navigation selection ─────────────────────────────────────────

    enum SidebarItem: Hashable {
        case importQueue
        case allEntries
        case entryType(EntryType)
        case trip(UUID)
        case map
        case stats
        case bucketList
        case rankings
        case settings
    }

    @EnvironmentObject var store: EntryStore
    @EnvironmentObject var tripStore: TripStore

    @State private var selection: SidebarItem? = .importQueue

    // Filters derived from sidebar selection
    @State private var showNewTrip  = false
    @State private var editingTrip: Trip? = nil
    @AppStorage("sidebar.tripsExpanded") private var tripsExpanded: Bool = false

    private var draftCount: Int  { store.entries.filter {  $0.isDraft }.count }
    private var entryCount: Int  { store.entries.filter { !$0.isDraft }.count }

    private var sortedTrips: [Trip] {
        tripStore.trips.sorted { $0.date > $1.date }
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {

                // ── Journal ──────────────────────────────────────────
                Section("Journal") {
                    sidebarRow("Import", symbol: "square.and.arrow.down",
                               item: .importQueue,
                               badge: draftCount > 0 ? draftCount : nil)
                    sidebarRow("Entries", symbol: "list.bullet",
                               item: .allEntries,
                               badge: entryCount > 0 ? entryCount : nil)
                    sidebarRow("Map", symbol: "map", item: .map)
                }

                // ── Entry types ───────────────────────────────────────
                Section("Entry Type") {
                    ForEach(EntryType.allCases, id: \.self) { et in
                        let count = store.entries.filter { !$0.isDraft && $0.entryType == et }.count
                        sidebarRow(et.label, symbol: et.symbol,
                                   item: .entryType(et),
                                   badge: count > 0 ? count : nil)
                    }
                }

                // ── Trips ─────────────────────────────────────────────
                Section {
                    DisclosureGroup(isExpanded: $tripsExpanded) {
                        ForEach(sortedTrips) { trip in
                            sidebarRow(trip.name, symbol: "map.fill",
                                       item: .trip(trip.id))
                                .contextMenu {
                                    Button("Edit Trip") { editingTrip = trip }
                                    Divider()
                                    Button("Delete Trip", role: .destructive) {
                                        tripStore.delete(id: trip.id)
                                        if selection == .trip(trip.id) { selection = .allEntries }
                                    }
                                }
                        }
                        Button {
                            showNewTrip = true
                        } label: {
                            Label("New Trip\u{2026}", systemImage: "plus")
                                .foregroundStyle(AppColors.primary)
                        }
                        .buttonStyle(.plain)
                    } label: {
                        sidebarRow("Trips", symbol: "map.fill", item: .map,
                                   badge: tripStore.trips.isEmpty ? nil : tripStore.trips.count)
                    }
                } // no header — the DisclosureGroup label row acts as header

                // ── Insights ─────────────────────────────────────────
                Section("Insights") {
                    sidebarRow("Stats",       symbol: "chart.bar",  item: .stats)
                    sidebarRow("Bucket List", symbol: "checklist",  item: .bucketList)
                    sidebarRow("Rankings",    symbol: "trophy",     item: .rankings)
                }

                // ── System ───────────────────────────────────────────
                Section {
                    sidebarRow("Settings", symbol: "gearshape", item: .settings)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Trailcam Journal")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(AppColors.primary)
        .sheet(isPresented: $showNewTrip) {
            TripEditSheet(trip: nil) { newTrip in tripStore.add(newTrip) }
        }
        .sheet(item: $editingTrip) { trip in
            TripEditSheet(trip: trip) { updated in tripStore.update(updated) }
        }
    }

    // MARK: - Sidebar row helper

    @ViewBuilder
    private func sidebarRow(
        _ label: String, symbol: String,
        item: SidebarItem, badge: Int? = nil
    ) -> some View {
        HStack(spacing: 6) {
            Label(label, systemImage: symbol)
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
        .tag(item)
    }

    // MARK: - Detail routing

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .importQueue {
        case .importQueue:
            MacImportPane()
        case .allEntries:
            MacEntriesPane()
        case .entryType(let et):
            MacEntriesPane(externalEntryTypeFilter: et)
        case .trip(let id):
            MacEntriesPane(externalTripFilter: id)
        case .map:
            MacMapPane()
        case .stats:
            MacStatsPane()
        case .bucketList:
            BucketListTabView()
        case .rankings:
            MacRankingsPane()
        case .settings:
            SettingsView()
        }
    }
}

// ── Trip edit sheet ───────────────────────────────────────────────────────────

private struct TripEditSheet: View {
    var trip: Trip?
    var onSave: (Trip) -> Void

    @State private var name:  String = ""
    @State private var date:  Date   = Date()
    @State private var notes: String = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(trip == nil ? "New Trip" : "Edit Trip")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            Divider()

            Form {
                TextField("Trip name", text: $name)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Divider()

            HStack {
                Spacer()
                Button("Save") {
                    var saved = trip ?? Trip(name: "", date: Date())
                    saved.name  = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    saved.date  = date
                    saved.notes = notes
                    onSave(saved)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(14)
        }
        .frame(width: 360)
        .onAppear {
            if let t = trip {
                name = t.name; date = t.date; notes = t.notes
            }
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
