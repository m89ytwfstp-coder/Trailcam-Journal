
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
        case trip(UUID)
        case map
        case pins
        case stats
        case lifeList
        case yearInReview
        case bucketList
        case rankings
        case settings
        // Spring features
        case springDashboard
        case arrivals
        case nestboxes
    }

    @EnvironmentObject var store:           EntryStore
    @EnvironmentObject var tripStore:       TripStore
    @EnvironmentObject var arrivalStore:    ArrivalStore
    @EnvironmentObject var nestboxStore:    NestboxStore
    @EnvironmentObject var customPinStore:  CustomPinStore

    @State private var selection: SidebarItem? = Self.defaultSelection
    /// Pin ID to focus when navigating from the Pins list to the map.
    @State private var mapFocusPinID: UUID? = nil

    @State private var showNewTrip      = false
    @State private var editingTrip:     Trip? = nil
    @AppStorage("sidebar.tripsExpanded") private var tripsExpanded: Bool = false

    /// Show spring dashboard as the default landing during 1 Apr – 15 Jul.
    private static var defaultSelection: SidebarItem {
        let cal  = Calendar.current
        let now  = Date()
        let day  = cal.ordinality(of: .day, in: .year, for: now) ?? 0
        let apr1 = cal.ordinality(of: .day, in: .year,
                                  for: cal.date(from: DateComponents(
                                      year: cal.component(.year, from: now),
                                      month: 4, day: 1))!)!
        let jul15 = cal.ordinality(of: .day, in: .year,
                                   for: cal.date(from: DateComponents(
                                       year: cal.component(.year, from: now),
                                       month: 7, day: 15))!)!
        return (day >= apr1 && day <= jul15) ? .springDashboard : .importQueue
    }

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
                    sidebarRow("Pins", symbol: "mappin",
                               item: .pins,
                               badge: customPinStore.pins.isEmpty ? nil : customPinStore.pins.count)

                    // ── Trips (standalone collapsible, no section header) ──
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
                        sidebarRow("Trips", symbol: "figure.hiking",
                                   item: .map,
                                   badge: tripStore.trips.isEmpty ? nil : tripStore.trips.count)
                    }
                }

                // ── Spring ────────────────────────────────────────────
                Section {
                    sidebarRow("Dashboard",     symbol: "leaf",         item: .springDashboard)
                    sidebarRow("Arrivals",      symbol: "bird",         item: .arrivals,
                               badge: arrivalStore.records.isEmpty ? nil : arrivalStore.records.count)
                    sidebarRow("Nestboxes",     symbol: "house",        item: .nestboxes,
                               badge: nestboxStore.nestboxes.isEmpty ? nil : nestboxStore.nestboxes.count)
                } header: {
                    HStack(spacing: 5) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.green.opacity(0.8))
                        Text("Spring")
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.06))
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                // ── Insights ─────────────────────────────────────────
                Section("Insights") {
                    sidebarRow("Stats",          symbol: "chart.bar",      item: .stats)
                    sidebarRow("Life List",      symbol: "list.star",      item: .lifeList)
                    sidebarRow("Year in Review", symbol: "calendar.badge.checkmark", item: .yearInReview)
                    sidebarRow("Bucket List",    symbol: "checklist",      item: .bucketList)
                    sidebarRow("Rankings",       symbol: "trophy",         item: .rankings)
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
        case .trip(let id):
            MacMapPane(focusedTripID: id)
                .environmentObject(customPinStore)
        case .map:
            MacMapPane(externalPinID: mapFocusPinID)
                .environmentObject(customPinStore)
        case .pins:
            MacCustomPinsPane(onNavigateToPin: { pinID in
                mapFocusPinID = pinID
                selection = .map
            })
            .environmentObject(customPinStore)
        case .stats:
            MacStatsPane()
        case .lifeList:
            LifeListView()
        case .yearInReview:
            YearInReviewView()
        case .bucketList:
            BucketListTabView()
        case .rankings:
            MacRankingsPane()
        case .settings:
            SettingsView()
        case .springDashboard:
            SpringDashboardView()
                .environmentObject(arrivalStore)
                .environmentObject(nestboxStore)
        case .arrivals:
            MacArrivalsPane()
                .environmentObject(arrivalStore)
        case .nestboxes:
            MacNestboxPane()
                .environmentObject(nestboxStore)
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
