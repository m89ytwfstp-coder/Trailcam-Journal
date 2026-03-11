
//
//  MacMapView.swift
//  Trailcam Journal
//
//  macOS Map — Kartverket tiles, entry pins, saved-location pins,
//  GPX trip tracks, cluster list sheet, and toolbar actions.
//

#if os(macOS)
import SwiftUI
import MapKit
import AppKit
import CoreLocation
import UniformTypeIdentifiers

// MARK: - Map style

enum MapStyle: String, CaseIterable {
    case topo
    case aerial
}

// MARK: - NSViewRepresentable wrapper

struct MacMapView: NSViewRepresentable {
    let entries:         [TrailEntry]
    let savedLocations:  [SavedLocation]
    var showLocations:   Bool
    var trips:           [Trip]      = []
    var tripEntryIDs:    Set<UUID>   = []
    var mapStyle:        MapStyle    = .topo
    var focusedTripID:   UUID?       = nil
    @Binding var recenterTrigger: Bool
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
        context.coordinator.syncTracks(trips: trips)
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncAnnotations(
            entries: entries,
            locations: savedLocations,
            showLocations: showLocations
        )
        context.coordinator.syncTracks(trips: trips)
        context.coordinator.updateMapStyle(mapStyle)
        context.coordinator.updateFocusedTrip(focusedTripID, trips: trips)
        // Recenter when trigger flips
        if context.coordinator.lastRecenterTrigger != recenterTrigger {
            context.coordinator.lastRecenterTrigger = recenterTrigger
            let norway = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 64.5, longitude: 17.0),
                span:   MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 15.0)
            )
            mapView.setRegion(norway, animated: true)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MacMapView
        weak var mapView: MKMapView?

        private var lastEntryIDs:     Set<UUID>   = []
        private var lastLocationKeys: Set<String> = []
        private var lastShowLocs:     Bool        = true
        private var lastTripEntryIDs: Set<UUID>   = []
        private var lastTripIDs:      Set<UUID>   = []
        private var currentMapStyle:   MapStyle    = .topo
        private var lastFocusedTripID: UUID?      = nil
        var lastRecenterTrigger:       Bool        = false
        private var didFitOnce = false

        init(parent: MacMapView) { self.parent = parent }

        // MARK: Annotation sync

        func syncAnnotations(entries: [TrailEntry],
                              locations: [SavedLocation],
                              showLocations: Bool) {
            guard let mapView else { return }

            let entryIDs     = Set(entries.map { $0.id })
            let locationKeys = Set(locations.map { $0.name })
            let tripEntryIDs = parent.tripEntryIDs

            let changed = entryIDs     != lastEntryIDs
                       || locationKeys != lastLocationKeys
                       || showLocations != lastShowLocs
                       || tripEntryIDs != lastTripEntryIDs
            guard changed else { return }

            lastEntryIDs     = entryIDs
            lastLocationKeys = locationKeys
            lastShowLocs     = showLocations
            lastTripEntryIDs = tripEntryIDs

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

            // Fit all entry pins the first time they appear, with minimum span
            // so Kartverket tiles always load (latitudeDelta < 0.08 is too zoomed in)
            if !entryAnnotations.isEmpty && !didFitOnce {
                didFitOnce = true
                let coords = entryAnnotations.map { $0.coordinate }
                var region = regionFitting(coords)
                region.span.latitudeDelta  = max(region.span.latitudeDelta,  0.08)
                region.span.longitudeDelta = max(region.span.longitudeDelta, 0.08)
                mapView.setRegion(region, animated: false)
            }
        }

        // MARK: Track sync

        func syncTracks(trips: [Trip]) {
            guard let mapView else { return }

            let tripIDs = Set(trips.map { $0.id })
            guard tripIDs != lastTripIDs else { return }
            lastTripIDs = tripIDs

            // Remove existing trip polylines (leave tile overlays intact)
            let stalePolylines = mapView.overlays.compactMap { $0 as? MKPolyline }
            mapView.removeOverlays(stalePolylines)

            // Add one polyline per trip that has at least 2 track points
            for trip in trips where trip.trackPoints.count >= 2 {
                let coords = trip.trackPoints.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                let polyline = MKPolyline(coordinates: coords, count: coords.count)
                mapView.addOverlay(polyline, level: .aboveLabels)
            }

            // Zoom to show all track content if this is the first import
            if !trips.isEmpty && !didFitOnce {
                let allCoords = trips.flatMap { trip in
                    trip.trackPoints.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    }
                }
                if !allCoords.isEmpty {
                    didFitOnce = true
                    let region = regionFitting(allCoords)
                    mapView.setRegion(region, animated: true)
                }
            }
        }

        // MARK: Map style

        func updateMapStyle(_ style: MapStyle) {
            guard let mapView, style != currentMapStyle else { return }
            currentMapStyle = style

            // Remove existing Kartverket tile overlays
            let tiles = mapView.overlays.compactMap { $0 as? KartverketTileOverlay }
            mapView.removeOverlays(tiles)

            switch style {
            case .topo:
                mapView.mapType = .standard
                let overlay = KartverketTileOverlay(layer: .topo)
                mapView.addOverlay(overlay, level: .aboveLabels)

            case .aerial:
                // Use MapKit's built-in satellite — no API key, always works
                mapView.mapType = .satellite
            }

            // Force track polylines to be re-added on top of the new base map
            lastTripIDs = []
            syncTracks(trips: parent.trips)
        }

        // MARK: Focused trip

        func updateFocusedTrip(_ id: UUID?, trips: [Trip]) {
            guard id != lastFocusedTripID else { return }
            lastFocusedTripID = id
            guard let id,
                  let trip = trips.first(where: { $0.id == id }),
                  trip.trackPoints.count >= 2,
                  let mapView else { return }
            let coords = trip.trackPoints.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            mapView.setRegion(regionFitting(coords), animated: true)
        }

        // MARK: MKMapViewDelegate — renderers

        func mapView(_ mapView: MKMapView,
                     rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = NSColor(AppColors.primary)
                renderer.lineWidth   = 3
                renderer.alpha       = 0.85
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: MKMapViewDelegate — annotation views

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
                view.clusteringIdentifier = nil
                return view
            }

            if let ann = annotation as? MacEntryAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "MacEntryPin", for: annotation
                ) as! MKMarkerAnnotationView
                view.canShowCallout       = false
                // Trip-associated entries get a teal tint to stand out on the track
                view.markerTintColor      = parent.tripEntryIDs.contains(ann.entry.id)
                    ? .systemTeal
                    : NSColor(AppColors.primary.opacity(0.95))
                view.glyphImage           = nil
                view.glyphText            = nil
                view.clusteringIdentifier = "macEntry"
                return view
            }

            return nil
        }

        // MARK: MKMapViewDelegate — tap handling

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            defer { mapView.deselectAnnotation(view.annotation, animated: false) }

            if let cluster = view.annotation as? MKClusterAnnotation {
                let members = cluster.memberAnnotations.compactMap { $0 as? MacEntryAnnotation }
                if members.count <= 6 {
                    parent.onSelectCluster(members.map { $0.entry })
                } else {
                    let coords = cluster.memberAnnotations.map { $0.coordinate }
                    mapView.setRegion(regionFitting(coords), animated: true)
                }
                return
            }

            if let ann = view.annotation as? MacEntryAnnotation {
                parent.onSelectEntry(ann.entry)
                return
            }
        }

        // MARK: Helpers

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

// MARK: - Trip list panel (popover content)

private struct TripListPanel: View {
    let trips:       [Trip]
    var onImport:    () -> Void
    var onSelectTrip: (UUID) -> Void
    var onDelete:    (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                Text("Trips")
                    .font(.headline)
                    .foregroundStyle(AppColors.primary)
                Spacer()
                Button("Import…") { onImport() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            if trips.isEmpty {
                Text("No trips imported yet.\nUse \"Import\u{2026}\" to add a GPX track.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(20)
                    .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(trips.sorted { $0.date > $1.date }) { trip in
                        Button {
                            onSelectTrip(trip.id)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.primary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trip.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                                        if !trip.trackPoints.isEmpty {
                                            Text("·")
                                            Text("\(trip.trackPoints.count) pts")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    onDelete(trip.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .help("Delete trip")
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.inset)
                .frame(maxHeight: 260)
            }
        }
        .frame(width: 300)
    }
}

// MARK: - Trip detail panel

private struct TripDetailPanel: View {
    let trip:              Trip
    let associatedEntries: [TrailEntry]
    var onClose:           () -> Void
    var onSelectEntry:     (TrailEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.name)
                        .font(.headline)
                        .lineLimit(2)
                    Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)

            Divider()

            // Stats row
            HStack(spacing: 16) {
                statCell(label: "Points", value: "\(trip.trackPoints.count)")
                if let start = trip.startDate, let end = trip.endDate {
                    let mins = Int(end.timeIntervalSince(start) / 60)
                    statCell(label: "Duration", value: "\(mins) min")
                }
                statCell(label: "Photos", value: "\(associatedEntries.count)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Associated entries grid
            if associatedEntries.isEmpty {
                Text("No entries linked to this trip.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 8
                    ) {
                        ForEach(associatedEntries.sorted { $0.date < $1.date }) { entry in
                            Button { onSelectEntry(entry) } label: {
                                MacThumbnail(entry: entry, cornerRadius: 8)
                                    .frame(height: 80)
                                    .clipped()
                            }
                            .buttonStyle(.plain)
                            .help(entry.displayTitle)
                        }
                    }
                    .padding(10)
                }
            }

            Spacer(minLength: 0)
        }
        .background(AppColors.background)
        .overlay(alignment: .leading) { Divider() }
    }

    @ViewBuilder
    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Full map pane (used by MacRoot sidebar)

struct MacMapPane: View {
    var focusedTripID: UUID? = nil   // set by MacRoot when a trip row is tapped

    @EnvironmentObject private var store:             EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore
    @EnvironmentObject private var tripStore:         TripStore

    @State private var showLocations    = true
    @State private var showTripPanel    = false
    @State private var importMessage:   String? = nil
    @State private var mapStyle:        MapStyle = .topo
    @State private var recenterTrigger  = false
    @State private var selectedTripID:  UUID?    = nil   // drives the detail panel

    @State private var selectedEntryID: UUID?
    @State private var clusterEntries:  [TrailEntry] = []
    @State private var showClusterSheet = false

    private var mappableEntries: [TrailEntry] {
        store.entries.filter {
            !$0.isDraft && $0.latitude != nil && $0.longitude != nil
        }
    }

    /// IDs of finalized entries whose date falls within any imported trip's time window (±5 min).
    private var tripAssociatedEntryIDs: Set<UUID> {
        var result = Set<UUID>()
        for trip in tripStore.trips {
            guard let start = trip.startDate, let end = trip.endDate else { continue }
            let window = start.addingTimeInterval(-300)...end.addingTimeInterval(300)
            for entry in store.entries where !entry.isDraft {
                if window.contains(entry.date) { result.insert(entry.id) }
            }
        }
        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                MacMapView(
                    entries:         mappableEntries,
                    savedLocations:  savedLocationStore.locations,
                    showLocations:   showLocations,
                    trips:           tripStore.trips,
                    tripEntryIDs:    tripAssociatedEntryIDs,
                    mapStyle:        mapStyle,
                    focusedTripID:   selectedTripID,
                    recenterTrigger: $recenterTrigger,
                    onSelectEntry: { entry in
                        selectedEntryID = entry.id
                    },
                    onSelectCluster: { entries in
                        clusterEntries   = entries
                        showClusterSheet = true
                    }
                )
                .ignoresSafeArea()

                if mappableEntries.isEmpty && tripStore.trips.isEmpty {
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

                // Import confirmation toast
                if let msg = importMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.thinMaterial,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .padding(.bottom, 20)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.3), value: importMessage)
                }
            }

            // Trip detail panel (slides in from the right when a trip is selected)
            if let tripID = selectedTripID,
               let trip = tripStore.trips.first(where: { $0.id == tripID }) {
                TripDetailPanel(
                    trip: trip,
                    associatedEntries: store.entries.filter { $0.tripID == tripID && !$0.isDraft },
                    onClose: { withAnimation(.easeInOut(duration: 0.25)) { selectedTripID = nil } },
                    onSelectEntry: { entry in selectedEntryID = entry.id }
                )
                .frame(width: 300)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTripID)
        .onAppear {
            // When opened from MacRoot with a focused trip, show that trip's panel
            if let id = focusedTripID {
                selectedTripID = id
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {

                // Toggle saved-location pins
                Button {
                    withAnimation { showLocations.toggle() }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: showLocations ? "bookmark.fill" : "bookmark")
                        Text(showLocations ? "Hide Pins" : "Show Pins")
                            .font(.caption2)
                    }
                }
                .help(showLocations ? "Hide pinned locations" : "Show pinned locations")

                // Recenter map on Norway
                Button { recenterTrigger.toggle() } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "location.fill")
                        Text("Recenter")
                            .font(.caption2)
                    }
                }
                .help("Re-center map on Norway")

                // Topo / Aerial segmented picker
                Picker("", selection: $mapStyle) {
                    Text("Topo").tag(MapStyle.topo)
                    Text("Aerial").tag(MapStyle.aerial)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .help("Switch between topo and aerial map")

                // Import a GPX track directly
                Button { importGPXFromOpenPanel() } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Trip")
                            .font(.caption2)
                    }
                }
                .help("Import a GPX file as a trip")

                // Trips list popover
                Button { showTripPanel.toggle() } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "map.fill")
                        Text(tripStore.trips.isEmpty ? "Trips" : "Trips (\(tripStore.trips.count))")
                            .font(.caption2)
                    }
                }
                .help("Show imported trips")
                .popover(isPresented: $showTripPanel, arrowEdge: .top) {
                    TripListPanel(
                        trips:    tripStore.trips,
                        onImport: {
                            showTripPanel = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                importGPXFromOpenPanel()
                            }
                        },
                        onSelectTrip: { id in
                            showTripPanel = false
                            withAnimation(.easeInOut(duration: 0.25)) { selectedTripID = id }
                        },
                        onDelete: deleteTrip
                    )
                }
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

    // MARK: - Import

    private func importGPXFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "gpx") ?? .data]
        panel.canChooseFiles        = true
        panel.allowsMultipleSelection = false
        panel.title = "Import GPX Track"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = try? Data(contentsOf: url) else {
            showToast("Could not read file.")
            return
        }

        let fallback = url.deletingPathExtension().lastPathComponent
        guard var trip = GPXParser.parse(data: data, fallbackName: fallback) else {
            showToast("Failed to parse GPX — no track points found.")
            return
        }

        // Save GPX file to Documents for future reference
        let filename = UUID().uuidString + ".gpx"
        if let dest = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(filename) {
            try? data.write(to: dest, options: .atomic)
            trip.gpxFilename = filename
        }

        tripStore.add(trip)

        // Auto-assign tripID to entries that fall within the trip's time window (±5 min)
        if let start = trip.startDate, let end = trip.endDate {
            let window = start.addingTimeInterval(-300)...end.addingTimeInterval(300)
            for i in store.entries.indices {
                guard !store.entries[i].isDraft else { continue }
                if window.contains(store.entries[i].date) {
                    store.entries[i].tripID = trip.id
                }
            }
        }

        showToast("Imported \"\(trip.name)\" \u{2014} \(trip.trackPoints.count) track points")
    }

    // MARK: - Delete

    private func deleteTrip(id: UUID) {
        // Delete the stored GPX file from Documents (best-effort)
        if let trip = tripStore.trips.first(where: { $0.id == id }),
           let filename = trip.gpxFilename, !filename.isEmpty,
           let url = FileManager.default
               .urls(for: .documentDirectory, in: .userDomainMask)
               .first?
               .appendingPathComponent(filename) {
            try? FileManager.default.removeItem(at: url)
        }
        tripStore.delete(id: id)
    }

    // MARK: - Toast helper

    private func showToast(_ message: String) {
        withAnimation { importMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation { importMessage = nil }
        }
    }
}
#endif
