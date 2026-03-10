
//
//  MacMapView.swift
//  Trailcam Journal
//
//  macOS Map — Kartverket tiles, entry pins, saved-location pins,
//  cluster list sheet, and toolbar toggle for pinned locations.
//

#if os(macOS)
import SwiftUI
import MapKit
import AppKit
import CoreLocation

// MARK: - NSViewRepresentable wrapper

struct MacMapView: NSViewRepresentable {
    let entries:         [TrailEntry]
    let savedLocations:  [SavedLocation]
    var showLocations:   Bool
    var onSelectEntry:   (TrailEntry)   -> Void
    var onSelectCluster: ([TrailEntry]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView

        // Kartverket topo tiles (same service as iOS)
        let overlay = KartverketTileOverlay(layer: .topo)
        mapView.addOverlay(overlay, level: .aboveLabels)

        // Register reusable annotation views
        mapView.register(MKMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: "MacEntryPin")
        mapView.register(MKMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: "MacClusterPin")
        mapView.register(MKMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: "MacLocationPin")

        // Default region: Norway
        mapView.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 64.5, longitude: 17.0),
                span:   MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 15.0)
            ),
            animated: false
        )

        context.coordinator.syncAnnotations(
            entries: entries,
            locations: savedLocations,
            showLocations: showLocations
        )
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncAnnotations(
            entries: entries,
            locations: savedLocations,
            showLocations: showLocations
        )
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MacMapView
        weak var mapView: MKMapView?
        private var lastEntryIDs:    Set<UUID> = []
        private var lastLocationKeys: Set<String> = []
        private var lastShowLocs:    Bool      = true
        private var didFitOnce = false

        init(parent: MacMapView) { self.parent = parent }

        func syncAnnotations(entries: [TrailEntry],
                              locations: [SavedLocation],
                              showLocations: Bool) {
            guard let mapView else { return }

            let entryIDs    = Set(entries.map { $0.id })
            let locationKeys = Set(locations.map { $0.name })
            let changed = entryIDs    != lastEntryIDs
                       || locationKeys != lastLocationKeys
                       || showLocations != lastShowLocs
            guard changed else { return }
            lastEntryIDs     = entryIDs
            lastLocationKeys = locationKeys
            lastShowLocs     = showLocations

            // Remove existing typed annotations
            let staleEntries   = mapView.annotations.compactMap { $0 as? MacEntryAnnotation }
            let staleLocations = mapView.annotations.compactMap { $0 as? MacLocationAnnotation }
            mapView.removeAnnotations(staleEntries)
            mapView.removeAnnotations(staleLocations)

            // Entry pins
            let entryAnnotations: [MacEntryAnnotation] = entries.compactMap { e in
                guard let lat = e.latitude, let lon = e.longitude,
                      lat != 0 || lon != 0 else { return nil }
                return MacEntryAnnotation(entry: e)
            }
            mapView.addAnnotations(entryAnnotations)

            // Saved-location pins (no clustering, orange)
            if showLocations {
                let locAnnotations = locations.map { MacLocationAnnotation(location: $0) }
                mapView.addAnnotations(locAnnotations)
            }

            // Fit all entry pins the first time they appear
            if !entryAnnotations.isEmpty && !didFitOnce {
                didFitOnce = true
                mapView.showAnnotations(entryAnnotations, animated: false)
            }
        }

        // Kartverket tile renderer
        func mapView(_ mapView: MKMapView,
                     rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // Pin / cluster annotation views
        func mapView(_ mapView: MKMapView,
                     viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "MacClusterPin", for: cluster
                ) as! MKMarkerAnnotationView
                view.canShowCallout  = false
                view.markerTintColor = NSColor(AppColors.primary)
                view.glyphText       = "\(cluster.memberAnnotations.count)"
                view.glyphImage      = nil
                return view
            }

            if annotation is MacLocationAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "MacLocationPin", for: annotation
                ) as! MKMarkerAnnotationView
                view.canShowCallout       = true
                view.markerTintColor      = .systemOrange
                view.glyphImage           = NSImage(
                    systemSymbolName: "bookmark.fill",
                    accessibilityDescription: nil
                )
                view.clusteringIdentifier = nil  // never cluster location pins
                return view
            }

            if annotation is MacEntryAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "MacEntryPin", for: annotation
                ) as! MKMarkerAnnotationView
                view.canShowCallout       = false
                view.markerTintColor      = NSColor(AppColors.primary.opacity(0.95))
                view.glyphImage           = nil
                view.glyphText            = nil
                view.clusteringIdentifier = "macEntry"
                return view
            }

            return nil
        }

        // Tap handling
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            defer { mapView.deselectAnnotation(view.annotation, animated: false) }

            if let cluster = view.annotation as? MKClusterAnnotation {
                let members = cluster.memberAnnotations.compactMap { $0 as? MacEntryAnnotation }
                if members.count <= 6 {
                    // Show list sheet for small clusters
                    parent.onSelectCluster(members.map { $0.entry })
                } else {
                    // Zoom in for large clusters
                    let coords = cluster.memberAnnotations.map { $0.coordinate }
                    mapView.setRegion(regionFitting(coords), animated: true)
                }
                return
            }

            if let ann = view.annotation as? MacEntryAnnotation {
                parent.onSelectEntry(ann.entry)
                return
            }
            // Location pins show native callout; no extra action needed
        }

        private func regionFitting(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
            guard !coords.isEmpty else {
                return MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 64.5, longitude: 17.0),
                    span:   MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 15)
                )
            }
            let minLat = coords.map(\.latitude).min()!
            let maxLat = coords.map(\.latitude).max()!
            let minLon = coords.map(\.longitude).min()!
            let maxLon = coords.map(\.longitude).max()!
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude:  (minLat + maxLat) / 2,
                    longitude: (minLon + maxLon) / 2
                ),
                span: MKCoordinateSpan(
                    latitudeDelta:  max((maxLat - minLat) * 1.4, 0.02),
                    longitudeDelta: max((maxLon - minLon) * 1.4, 0.02)
                )
            )
        }
    }
}

// MARK: - Annotation models

final class MacEntryAnnotation: NSObject, MKAnnotation {
    let entry: TrailEntry
    dynamic var coordinate: CLLocationCoordinate2D

    var title: String?    { entry.displayTitle }
    var subtitle: String? { entry.date.formatted(date: .abbreviated, time: .shortened) }

    init(entry: TrailEntry) {
        self.entry      = entry
        self.coordinate = CLLocationCoordinate2D(
            latitude:  entry.latitude  ?? 0,
            longitude: entry.longitude ?? 0
        )
        super.init()
    }
}

final class MacLocationAnnotation: NSObject, MKAnnotation {
    let location: SavedLocation
    dynamic var coordinate: CLLocationCoordinate2D

    var title: String? { location.name }

    init(location: SavedLocation) {
        self.location   = location
        self.coordinate = CLLocationCoordinate2D(
            latitude:  location.latitude,
            longitude: location.longitude
        )
        super.init()
    }
}

// MARK: - Cluster list sheet

struct MacClusterListSheet: View {
    let entries: [TrailEntry]
    var onSelect: (TrailEntry) -> Void

    @EnvironmentObject private var savedLocationStore: SavedLocationStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                Text("\(entries.count) Sightings at this location")
                    .font(.headline)
                    .foregroundStyle(AppColors.primary)
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            List(entries.sorted { $0.date > $1.date }) { entry in
                Button {
                    onSelect(entry)
                } label: {
                    HStack(spacing: 12) {
                        MacThumbnail(entry: entry)
                            .frame(width: 60, height: 46)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.displayTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.primary)
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            if let cam = entry.camera, !cam.isEmpty {
                                Label(cam, systemImage: "camera")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.white)
                .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
        }
        .frame(minWidth: 360, minHeight: 280)
        .background(AppColors.background)
    }
}

// MARK: - Full map pane (used by MacRoot sidebar)

struct MacMapPane: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore
    @EnvironmentObject private var tripStore: TripStore

    @State private var showLocations   = true
    @State private var selectedEntryID: UUID?
    @State private var clusterEntries: [TrailEntry] = []
    @State private var showClusterSheet = false

    private var mappableEntries: [TrailEntry] {
        store.entries.filter {
            !$0.isDraft && $0.latitude != nil && $0.longitude != nil
        }
    }

    var body: some View {
        ZStack {
            MacMapView(
                entries:        mappableEntries,
                savedLocations: savedLocationStore.locations,
                showLocations:  showLocations,
                onSelectEntry: { entry in
                    selectedEntryID = entry.id
                },
                onSelectCluster: { entries in
                    clusterEntries   = entries
                    showClusterSheet = true
                }
            )
            .ignoresSafeArea()

            if mappableEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No entries with GPS yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation { showLocations.toggle() }
                } label: {
                    Label(
                        showLocations ? "Hide Saved Locations" : "Show Saved Locations",
                        systemImage: showLocations
                            ? "bookmark.fill"
                            : "bookmark"
                    )
                }
                .help(showLocations ? "Hide pinned locations" : "Show pinned locations")
            }
        }
        // Entry detail sheet
        .sheet(isPresented: Binding(
            get: { selectedEntryID != nil },
            set: { if !$0 { selectedEntryID = nil } }
        )) {
            if let id = selectedEntryID {
                MacEntryDetailView(entryID: id)
                    .environmentObject(store)
                    .environmentObject(savedLocationStore)
                    .environmentObject(tripStore)
            }
        }
        // Cluster list sheet
        .sheet(isPresented: $showClusterSheet) {
            MacClusterListSheet(entries: clusterEntries) { entry in
                showClusterSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedEntryID = entry.id
                }
            }
            .environmentObject(savedLocationStore)
        }
    }
}
#endif
