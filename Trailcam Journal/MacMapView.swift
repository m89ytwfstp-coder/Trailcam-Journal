
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
    var focusedTripID:  UUID?   = nil
    var focusedHubID:   UUID?   = nil
    var hubs:           [Hub]   = []
    @Binding var recenterTrigger: Bool
    var onSelectEntry:        (TrailEntry) -> Void
    var onSelectCluster:      ([TrailEntry]) -> Void
    var onRightClickCoord:    ((CLLocationCoordinate2D) -> Void)? = nil

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

        // Right-click to create a hub
        let rightClick = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleRightClick(_:))
        )
        rightClick.buttonMask = 0x2
        mapView.addGestureRecognizer(rightClick)

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
        context.coordinator.updateFocusedHub(focusedHubID, hubs: hubs)
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
        private var currentMapStyle:   MapStyle = .topo
        private var lastFocusedTripID: UUID?    = nil
        private var lastFocusedHubID:  UUID?    = nil
        var lastRecenterTrigger:       Bool      = false
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
                // Orange shows well on both topo and aerial satellite
                renderer.strokeColor = .systemOrange
                renderer.lineWidth   = 3.5
                renderer.alpha       = 0.9
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

        // MARK: Focused hub

        func updateFocusedHub(_ id: UUID?, hubs: [Hub]) {
            guard id != lastFocusedHubID else { return }
            lastFocusedHubID = id
            guard let id,
                  let hub = hubs.first(where: { $0.id == id }),
                  let mapView else { return }
            // Zoom to hub centre at roughly 1:50 000 — comfortable for a 10 km hub radius
            let region = MKCoordinateRegion(
                center: hub.coordinate,
                span:   MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.15)
            )
            mapView.setRegion(region, animated: true)
        }

        // MARK: Right-click — hub creation

        @objc func handleRightClick(_ recognizer: NSClickGestureRecognizer) {
            guard let mapView else { return }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onRightClickCoord?(coordinate)
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

// MARK: - Hub strip (horizontal pill bar floating over the map)

private struct HubStrip: View {
    let hubs:           [Hub]
    var selectedHubID:  UUID?
    var onSelectHub:    (Hub) -> Void
    var onNewHub:       () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(hubs.sorted { $0.name < $1.name }) { hub in
                    Button { onSelectHub(hub) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption2)
                            Text(hub.name)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            selectedHubID == hub.id
                                ? AnyShapeStyle(AppColors.primary)
                                : AnyShapeStyle(.thinMaterial),
                            in: Capsule()
                        )
                        .foregroundStyle(selectedHubID == hub.id ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }

                // Add new hub
                Button { onNewHub() } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                        .padding(6)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Right-click anywhere on the map to place a hub, or tap + and enter coordinates")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Hub detail panel

private struct HubDetailPanel: View {
    let hub:               Hub
    let associatedEntries: [TrailEntry]
    var onClose:           () -> Void
    var onSelectEntry:     (TrailEntry) -> Void
    var onDeleteHub:       () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hub.name)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(Int(hub.radius / 1000)) km radius")
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
                statCell(label: "Entries", value: "\(associatedEntries.count)")
                if let earliest = associatedEntries.map(\.date).min() {
                    statCell(label: "First Visit",
                             value: earliest.formatted(.dateTime.month(.abbreviated).year()))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Associated entries grid
            if associatedEntries.isEmpty {
                Text("No entries within \(Int(hub.radius / 1000)) km of this hub.")
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
                        ForEach(associatedEntries.sorted { $0.date > $1.date }) { entry in
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

            Divider()

            // Delete hub button
            Button(role: .destructive) { onDeleteHub() } label: {
                Label("Delete Hub", systemImage: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(12)
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

    @EnvironmentObject private var store:              EntryStore
    @EnvironmentObject private var savedLocationStore:  SavedLocationStore
    @EnvironmentObject private var tripStore:           TripStore
    @EnvironmentObject private var hubStore:            HubStore

    @State private var showLocations    = true
    @State private var showTripPanel    = false
    @State private var importMessage:   String? = nil
    @State private var mapStyle:        MapStyle = .topo
    @State private var recenterTrigger  = false
    @State private var selectedTripID:  UUID?    = nil
    @State private var selectedHubID:   UUID?    = nil

    // Hub creation
    @State private var pendingHubCoord:   CLLocationCoordinate2D? = nil
    @State private var showHubNameSheet   = false
    @State private var newHubName         = ""

    @State private var selectedEntryID: UUID?
    @State private var clusterEntries:  [TrailEntry] = []
    @State private var showClusterSheet = false

    /// Entries within a hub's radius, sorted newest-first.
    private func entries(nearHub hub: Hub) -> [TrailEntry] {
        store.entries.filter { entry in
            guard !entry.isDraft,
                  let lat = entry.latitude,
                  let lon = entry.longitude else { return false }
            return hub.clLocation.distance(from: CLLocation(latitude: lat, longitude: lon)) <= hub.radius
        }.sorted { $0.date > $1.date }
    }

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
            ZStack(alignment: .top) {
                MacMapView(
                    entries:         mappableEntries,
                    savedLocations:  savedLocationStore.locations,
                    showLocations:   showLocations,
                    trips:           tripStore.trips,
                    tripEntryIDs:    tripAssociatedEntryIDs,
                    mapStyle:        mapStyle,
                    focusedTripID:   selectedTripID,
                    focusedHubID:    selectedHubID,
                    hubs:            hubStore.hubs,
                    recenterTrigger: $recenterTrigger,
                    onSelectEntry: { entry in
                        selectedEntryID = entry.id
                    },
                    onSelectCluster: { entries in
                        clusterEntries   = entries
                        showClusterSheet = true
                    },
                    onRightClickCoord: { coord in
                        pendingHubCoord = coord
                        newHubName      = ""
                        showHubNameSheet = true
                    }
                )
                .ignoresSafeArea()

                // Hub strip — always visible, floating at top of map
                if !hubStore.hubs.isEmpty || true { // always show so user can add first hub
                    VStack(spacing: 0) {
                        HubStrip(
                            hubs:          hubStore.hubs,
                            selectedHubID: selectedHubID,
                            onSelectHub: { hub in
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    if selectedHubID == hub.id {
                                        selectedHubID = nil   // toggle off
                                    } else {
                                        selectedHubID  = hub.id
                                        selectedTripID = nil  // close trip panel
                                    }
                                }
                            },
                            onNewHub: {
                                pendingHubCoord  = nil
                                newHubName       = ""
                                showHubNameSheet = true
                            }
                        )
                        .background(.ultraThinMaterial)
                        Spacer()
                    }
                }

                if mappableEntries.isEmpty && tripStore.trips.isEmpty && hubStore.hubs.isEmpty {
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

                // Toast
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

            // Hub detail panel
            if let hubID = selectedHubID,
               let hub = hubStore.hubs.first(where: { $0.id == hubID }) {
                HubDetailPanel(
                    hub: hub,
                    associatedEntries: entries(nearHub: hub),
                    onClose:      { withAnimation(.easeInOut(duration: 0.25)) { selectedHubID = nil } },
                    onSelectEntry: { entry in selectedEntryID = entry.id },
                    onDeleteHub:  {
                        withAnimation(.easeInOut(duration: 0.25)) { selectedHubID = nil }
                        hubStore.delete(id: hubID)
                    }
                )
                .frame(width: 300)
                .transition(.move(edge: .trailing))
            }

            // Trip detail panel
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
        .animation(.easeInOut(duration: 0.25), value: selectedHubID)
        .animation(.easeInOut(duration: 0.25), value: selectedTripID)
        .onAppear {
            if let id = focusedTripID { selectedTripID = id }
        }
        // Hub name sheet (appears after right-click or tapping "+")
        .sheet(isPresented: $showHubNameSheet) {
            HubNameSheet(
                name:       $newHubName,
                coordinate: pendingHubCoord,
                onSave: { name, coord in
                    let hub = Hub(name: name,
                                  latitude:  coord.latitude,
                                  longitude: coord.longitude)
                    hubStore.add(hub)
                    withAnimation { selectedHubID = hub.id }
                    showHubNameSheet = false
                },
                onCancel: { showHubNameSheet = false }
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {

                Button {
                    withAnimation { showLocations.toggle() }
                } label: {
                    Label(showLocations ? "Hide Pins" : "Show Pins",
                          systemImage: showLocations ? "bookmark.fill" : "bookmark")
                }
                .help(showLocations ? "Hide saved-location pins" : "Show saved-location pins")

                Button { recenterTrigger.toggle() } label: {
                    Label("Recenter", systemImage: "location.fill")
                }
                .help("Re-centre map on Norway")

                Picker("", selection: $mapStyle) {
                    Text("Topo").tag(MapStyle.topo)
                    Text("Aerial").tag(MapStyle.aerial)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
                .help("Switch map style")

                // Trips — Import is inside the popover, keeping the toolbar uncluttered
                Button { showTripPanel.toggle() } label: {
                    Label(
                        tripStore.trips.isEmpty ? "Trips" : "Trips (\(tripStore.trips.count))",
                        systemImage: "point.bottomleft.forward.to.point.topright.scurvepath.fill"
                    )
                }
                .help("Show imported GPX trips")
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
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedTripID = id
                                selectedHubID  = nil
                            }
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

    // MARK: - Import

    private func importGPXFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes    = [UTType(filenameExtension: "gpx") ?? .data]
        panel.canChooseFiles         = true
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

        // Auto-name from track date + nearest saved location (replaces generic Garmin names)
        trip.name = autoName(for: trip)

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

        // Stamp tripID on entries that fall within the trip's time window (±5 min)
        if let start = trip.startDate, let end = trip.endDate {
            let window = start.addingTimeInterval(-300)...end.addingTimeInterval(300)
            for i in store.entries.indices {
                guard !store.entries[i].isDraft else { continue }
                if window.contains(store.entries[i].date) {
                    store.entries[i].tripID = trip.id
                }
            }
        }

        showToast("Imported \"\(trip.name)\" \u{2014} \(trip.trackPoints.count) pts")
    }

    /// Builds a descriptive name from the track's start date and nearest saved location.
    /// Replaces Garmin's generic "Location Activity" style names.
    private func autoName(for trip: Trip) -> String {
        let refDate = trip.startDate ?? trip.date
        let dateStr = refDate.formatted(.dateTime.month(.abbreviated).day())

        // Centroid of all track points
        let pts = trip.trackPoints
        guard !pts.isEmpty else { return dateStr }
        let avgLat = pts.map(\.latitude).reduce(0, +)  / Double(pts.count)
        let avgLon = pts.map(\.longitude).reduce(0, +) / Double(pts.count)
        let centroid = CLLocation(latitude: avgLat, longitude: avgLon)

        // Find nearest saved location within 50 km
        let nearest = savedLocationStore.locations.min {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: centroid) <
            CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: centroid)
        }

        if let loc = nearest,
           CLLocation(latitude: loc.latitude, longitude: loc.longitude)
               .distance(from: centroid) < 50_000 {
            return "\(dateStr) \u{00B7} \(loc.name)"
        }

        // Fall back to nearest hub name if within 20 km
        let nearestHub = hubStore.hubs.min {
            $0.clLocation.distance(from: centroid) < $1.clLocation.distance(from: centroid)
        }
        if let hub = nearestHub, hub.clLocation.distance(from: centroid) < 20_000 {
            return "\(dateStr) \u{00B7} \(hub.name)"
        }

        return dateStr
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
// MARK: - Hub name sheet

private struct HubNameSheet: View {
    @Binding var name: String
    /// Non-nil when triggered by a right-click with a known coordinate;
    /// nil when triggered by the "+" button (user types coordinates manually).
    var coordinate: CLLocationCoordinate2D?
    var onSave:   (String, CLLocationCoordinate2D) -> Void
    var onCancel: () -> Void

    @State private var latText  = ""
    @State private var lonText  = ""

    private var resolvedCoord: CLLocationCoordinate2D? {
        if let c = coordinate { return c }
        guard let lat = Double(latText), let lon = Double(lonText) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Hub")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            Divider()

            Form {
                TextField("Hub name (e.g. Cabin)", text: $name)

                if coordinate == nil {
                    TextField("Latitude", text: $latText)
                    TextField("Longitude", text: $lonText)
                } else {
                    LabeledContent("Latitude",  value: String(format: "%.5f", coordinate!.latitude))
                    LabeledContent("Longitude", value: String(format: "%.5f", coordinate!.longitude))
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Divider()

            HStack {
                Spacer()
                Button("Add Hub") {
                    guard let coord = resolvedCoord,
                          !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    onSave(name.trimmingCharacters(in: .whitespaces), coord)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || resolvedCoord == nil)
            }
            .padding(14)
        }
        .frame(width: 340)
    }
}
#endif
