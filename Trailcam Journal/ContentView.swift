#if os(iOS)
//
//  ContentView.swift
//  Trailcam Journal
//
//  Cleaned: TabView + MapTabView (cluster sheet fixed + pretty UI)
//

import SwiftUI
import UIKit
import MapKit

private func applyTabBarAppearance() {
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = UIColor(AppColors.background)

    // Subtle top border line
    appearance.shadowColor = UIColor(AppColors.primary.opacity(0.12))

    UITabBar.appearance().standardAppearance = appearance
    if #available(iOS 15.0, *) {
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    UITabBar.appearance().tintColor = UIColor(AppColors.primary)
    UITabBar.appearance().unselectedItemTintColor = UIColor(AppColors.primary.opacity(0.45))
}

#endif

struct ContentView: View {
    @EnvironmentObject var store: EntryStore

    var body: some View {
        let draftCount = store.entries.filter { $0.isDraft }.count

        TabView {
            ImportWorkflowView()
                .tabItem { Label("Import", systemImage: "square.and.arrow.down") }
                .badge(draftCount)

            EntriesListView()
                .tabItem { Label("Entries", systemImage: "list.bullet") }

            MapTabView()
                .tabItem { Label("Map", systemImage: "map") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            MoreHomeView()
                .tabItem { Label("More", systemImage: "ellipsis") }
        }
        .onAppear { applyTabBarAppearance() }
    }
}

// MARK: - MapTabView

private struct ClusterSelection: Identifiable {
    let id = UUID()
    let entries: [TrailEntry]
}

struct MapTabView: View {
    @EnvironmentObject var store: EntryStore
    @EnvironmentObject var savedLocationStore: SavedLocationStore

    @AppStorage("settings.autoRecenterMap") private var autoRecenterMap: Bool = true

    // Trondheim default
    private let trondheimCenter = CLLocationCoordinate2D(latitude: 63.4305, longitude: 10.3951)

    @State private var mapCenter = CLLocationCoordinate2D(latitude: 63.4305, longitude: 10.3951)

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 63.4305, longitude: 10.3951),
        span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
    )

    @State private var showSaveLocationPrompt = false
    @State private var newLocationName = ""

    @State private var showManageLocations = false

    @State private var selectedEntry: TrailEntry?
    @State private var clusterSelection: ClusterSelection?

    private var locatedEntries: [TrailEntry] {
        store.entries.filter { !$0.isDraft && $0.latitude != nil && $0.longitude != nil }
    }

    // MARK: - Map actions

    private func recenterToTrondheim() {
        region = MKCoordinateRegion(
            center: trondheimCenter,
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        )
    }

    private func recenterOnEntries() {
        let coords = locatedEntries.compactMap { entry -> CLLocationCoordinate2D? in
            guard let lat = entry.latitude, let lon = entry.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        guard !coords.isEmpty else {
            region = MKCoordinateRegion(
                center: trondheimCenter,
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
            return
        }

        let avgLat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
        let avgLon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)

        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        )
    }

    private func recenterOnSavedLocation(_ loc: SavedLocation) {
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
    }

    private func saveCurrentCenterAsLocation() {
        let trimmed = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let loc = SavedLocation(
            name: trimmed,
            latitude: mapCenter.latitude,
            longitude: mapCenter.longitude
        )
        savedLocationStore.add(loc)
        newLocationName = ""
    }

    private func thumbnailName(for speciesNameNO: String?) -> String? {
        guard let name = speciesNameNO else { return nil }
        return SpeciesCatalog.all.first(where: { $0.nameNO == name })?.thumbnailName
    }

    private func entryMetaLine(for entry: TrailEntry) -> String? {
        var parts: [String] = []
        if let camera = entry.camera, !camera.isEmpty {
            parts.append(camera)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private struct ClusterEntryRow: View {
        let entry: TrailEntry
        let thumbnailName: String?
        let meta: String?

        var body: some View {
            HStack(spacing: 12) {
                thumbnail
                texts
                Spacer()
                chevron
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.surface.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }

        private var thumbnail: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.surface)

                if let name = thumbnailName,
                   let uiImage = UIImage(named: name) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(width: 54, height: 54)
        }

        private var texts: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.species ?? "Unknown species")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                if let meta {
                    Text(meta)
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
        }

        private var chevron: some View {
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                KartverketMapView(
                    entries: locatedEntries,
                    region: $region,
                    mapCenter: $mapCenter,
                    onSelectEntry: { entry in
                        DispatchQueue.main.async {
                            selectedEntry = entry
                        }
                    },
                    onSelectCluster: { entries in
                        DispatchQueue.main.async {
                            let uniqueSorted = Dictionary(grouping: entries, by: { $0.id })
                                .compactMap { $0.value.first }
                                .sorted { $0.date > $1.date }

                            clusterSelection = uniqueSorted.isEmpty ? nil : ClusterSelection(entries: uniqueSorted)
                        }
                    }
                )
                .onAppear {
                    if autoRecenterMap { recenterOnEntries() }
                }
                .onChange(of: store.entries.count) { _, _ in
                    if autoRecenterMap { recenterOnEntries() }
                }

                headerOverlay
            }
            .appScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedEntry) { entry in
                EntryDetailView(entryID: entry.id)
            }
            .sheet(item: $clusterSelection) { selection in
                clusterSheet(selection: selection)
            }
            .alert("Save location", isPresented: $showSaveLocationPrompt) {
                TextField("Name (e.g. Revehiet)", text: $newLocationName)
                Button("Save") { saveCurrentCenterAsLocation() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will save the current map center as a favourite location.")
            }
            .sheet(isPresented: $showManageLocations) {
                ManageSavedLocationsView()
            }
        }
    }

    private var headerOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppHeader(
                title: "Map",
                subtitle: "Kartverket topo + saved locations"
            )

            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button {
                            showSaveLocationPrompt = true
                        } label: {
                            Label("Save", systemImage: "plus")
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button {
                            showManageLocations = true
                        } label: {
                            Label("Manage", systemImage: "list.bullet")
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        // ✅ Changed: always Trondheim
                        Button {
                            recenterToTrondheim()
                        } label: {
                            Label("Trondheim", systemImage: "scope")
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 8)
                }

                if !savedLocationStore.locations.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(savedLocationStore.locations) { loc in
                                Button {
                                    recenterOnSavedLocation(loc)
                                } label: {
                                    Text(loc.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColors.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(AppColors.surface.opacity(0.92))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(AppColors.primary.opacity(0.12), lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(
            Rectangle()
                .fill(AppColors.background.opacity(0.92))
                .ignoresSafeArea(edges: .top)
        )
    }

    private func clusterSheet(selection: ClusterSelection) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(selection.entries) { entry in
                        let thumb = thumbnailName(for: entry.species)
                        let meta = entryMetaLine(for: entry)

                        Button {
                            selectedEntry = entry
                            clusterSelection = nil
                        } label: {
                            ClusterEntryRow(entry: entry, thumbnailName: thumb, meta: meta)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .appScreenBackground()
            .navigationTitle("Choose entry")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { clusterSelection = nil }
                }
            }
        }
    }
}
