
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
    var trips:           [Trip]         = []
    var tripEntryIDs:    Set<UUID>      = []
    var mapStyle:        MapStyle       = .topo
    var focusedTripID:   UUID?          = nil
    // Custom-pin layer
    var customPins:         [CustomPin] = []
    var showCustomPins:     Bool        = true
    var showInfrastructure: Bool        = true
    var showWildlifeSigns:  Bool        = true
    var showTerrain:        Bool        = true
    var showInactivePins:   Bool        = false
    var ghostPinCoord:      CLLocationCoordinate2D? = nil
    var focusedPinID:       UUID?       = nil
    var focusedLocationID:  UUID?       = nil
    var hubs:                  [SavedLocation]                               = []
    var onLongPress:           ((CLLocationCoordinate2D) -> Void)? = nil
    var onSelectCustomPin:     ((CustomPin) -> Void)?              = nil
    var onSelectSavedLocation: ((SavedLocation) -> Void)?          = nil
    var onSelectHub:           ((SavedLocation) -> Void)?          = nil
    @Binding var recenterTrigger: Bool
    var clusterListMax:       Int = 6
    var onSelectEntry:        (TrailEntry) -> Void
    var onSelectCluster:      ([TrailEntry]) -> Void

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
        mapView.register(MKAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: "MacCustomPin")
        mapView.register(MKAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: "MacGhostPin")
        mapView.register(MKMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: "MacSavedLocationPin")

        // Long-press gesture for pin placement
        let press = NSPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        press.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(press)

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
            showLocations: showLocations,
            hubs: hubs
        )
        context.coordinator.syncTracks(trips: trips)
        context.coordinator.syncCustomPins(
            customPins,
            showCustomPins:     showCustomPins,
            showInactive:       showInactivePins,
            showInfrastructure: showInfrastructure,
            showWildlifeSigns:  showWildlifeSigns,
            showTerrain:        showTerrain,
            ghostCoord:         ghostPinCoord
        )

        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncAnnotations(
            entries: entries,
            locations: savedLocations,
            showLocations: showLocations,
            hubs: hubs
        )
        context.coordinator.syncTracks(trips: trips)
        context.coordinator.updateMapStyle(mapStyle)
        context.coordinator.updateFocusedTrip(focusedTripID, trips: trips)
        context.coordinator.syncCustomPins(
            customPins,
            showCustomPins:     showCustomPins,
            showInactive:       showInactivePins,
            showInfrastructure: showInfrastructure,
            showWildlifeSigns:  showWildlifeSigns,
            showTerrain:        showTerrain,
            ghostCoord:         ghostPinCoord
        )
        context.coordinator.updateFocusedPin(focusedPinID, pins: customPins)
        context.coordinator.updateFocusedLocation(focusedLocationID, locations: savedLocations)
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
        private var lastSavedLocationIDs:       Set<UUID>   = []
        private var lastTripIDs:      Set<UUID>   = []
        private var currentMapStyle:   MapStyle = .topo
        private var lastFocusedTripID: UUID?      = nil
        private var lastFocusedPinID:      UUID?   = nil
        private var lastFocusedLocationID: UUID?   = nil
        private var lastCustomPinKey:  String     = ""
        var lastRecenterTrigger:       Bool        = false
        private var didFitOnce = false

        init(parent: MacMapView) { self.parent = parent }

        // MARK: Long-press — pin placement

        @objc func handleLongPress(_ gesture: NSPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            let pt = gesture.location(in: mapView)
            let coord = mapView.convert(pt, toCoordinateFrom: mapView)
            parent.onLongPress?(coord)
        }

        // MARK: Custom pin sync

        func syncCustomPins(_ pins: [CustomPin],
                            showCustomPins: Bool,
                            showInactive: Bool,
                            showInfrastructure: Bool,
                            showWildlifeSigns: Bool,
                            showTerrain: Bool,
                            ghostCoord: CLLocationCoordinate2D?) {
            guard let mapView else { return }

            // Build a lightweight key to skip redundant syncs
            let pinHash = pins.map { "\($0.id)\($0.isActive)\($0.type)" }
                              .sorted().joined()
            let ghostStr = ghostCoord.map { "\($0.latitude),\($0.longitude)" } ?? "nil"
            let key = "\(pinHash)|\(showCustomPins)|\(showInactive)|\(showInfrastructure)|\(showWildlifeSigns)|\(showTerrain)|\(ghostStr)"
            guard key != lastCustomPinKey else { return }
            lastCustomPinKey = key

            // Remove stale custom-pin and ghost annotations
            let staleCustom = mapView.annotations.compactMap { $0 as? MacCustomPinAnnotation }
            let staleGhost  = mapView.annotations.compactMap { $0 as? MacGhostPinAnnotation }
            mapView.removeAnnotations(staleCustom)
            mapView.removeAnnotations(staleGhost)

            // Ghost pin while quick-add sheet is open
            if let coord = ghostCoord {
                mapView.addAnnotation(MacGhostPinAnnotation(coordinate: coord))
            }

            guard showCustomPins else { return }

            let visible = pins.filter { pin in
                if !showInactive && !pin.isActive { return false }
                switch pin.type.category {
                case .infrastructure: return showInfrastructure
                case .wildlifeSign:   return showWildlifeSigns
                case .terrain:        return showTerrain
                }
            }
            mapView.addAnnotations(visible.map { MacCustomPinAnnotation(pin: $0) })
        }

        // MARK: Focused pin — navigate from Pins list

        func updateFocusedPin(_ id: UUID?, pins: [CustomPin]) {
            guard id != lastFocusedPinID else { return }
            lastFocusedPinID = id
            guard let id,
                  let pin = pins.first(where: { $0.id == id }),
                  let mapView else { return }
            let region = MKCoordinateRegion(
                center: pin.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            mapView.setRegion(region, animated: true)
        }

        // MARK: Focused location — zoom in when a saved-location / hub pin is tapped

        func updateFocusedLocation(_ id: UUID?, locations: [SavedLocation]) {
            guard id != lastFocusedLocationID else { return }
            lastFocusedLocationID = id

            guard let mapView else { return }

            // Remove any existing hub radius circle
            let staleCircles = mapView.overlays.compactMap { $0 as? MKCircle }
            mapView.removeOverlays(staleCircles)

            guard let id, let loc = locations.first(where: { $0.id == id }) else { return }

            // Draw radius circle for hubs
            if let radius = loc.radius {
                let circle = MKCircle(center: loc.coordinate, radius: radius)
                mapView.addOverlay(circle, level: .aboveLabels)
            }

            // Zoom: use hub radius (with padding) or a sensible default for plain pins.
            let spanDeg: CLLocationDegrees
            if let radius = loc.radius {
                spanDeg = max((radius / 111_000) * 2.5, 0.008)
            } else {
                spanDeg = 0.04
            }
            mapView.setRegion(
                MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: spanDeg, longitudeDelta: spanDeg)
                ),
                animated: true
            )
        }

        // MARK: Annotation sync

        func syncAnnotations(entries: [TrailEntry],
                              locations: [SavedLocation],
                              showLocations: Bool,
                              hubs: [SavedLocation] = []) {
            guard let mapView else { return }

            let entryIDs     = Set(entries.map { $0.id })
            let locationKeys = Set(locations.map { $0.name })
            let tripEntryIDs = parent.tripEntryIDs
            let hubIDs       = Set(hubs.map { $0.id })

            let changed = entryIDs     != lastEntryIDs
                       || locationKeys != lastLocationKeys
                       || showLocations != lastShowLocs
                       || tripEntryIDs != lastTripEntryIDs
                       || hubIDs       != lastSavedLocationIDs
            guard changed else { return }

            lastEntryIDs     = entryIDs
            lastLocationKeys = locationKeys
            lastShowLocs     = showLocations
            lastTripEntryIDs = tripEntryIDs
            lastSavedLocationIDs       = hubIDs

            // Remove existing typed annotations
            let staleEntries   = mapView.annotations.compactMap { $0 as? MacEntryAnnotation }
            let staleLocations = mapView.annotations.compactMap { $0 as? MacLocationAnnotation }
            let staleSavedLocations      = mapView.annotations.compactMap { $0 as? MacSavedLocationAnnotation }
            mapView.removeAnnotations(staleEntries)
            mapView.removeAnnotations(staleLocations)
            mapView.removeAnnotations(staleSavedLocations)

            // Entry pins
            let entryAnnotations: [MacEntryAnnotation] = entries.compactMap { e in
                guard let lat = e.latitude, let lon = e.longitude,
                      lat != 0 || lon != 0 else { return nil }
                return MacEntryAnnotation(entry: e)
            }
            mapView.addAnnotations(entryAnnotations)

            // Saved-location pins — plain bookmarks only (hubs get their own annotation)
            if showLocations {
                let plainLocations = locations.filter { !$0.isHub }
                let locAnnotations = plainLocations.map { MacLocationAnnotation(location: $0) }
                mapView.addAnnotations(locAnnotations)
            }

            // SavedLocation pins — always visible (not gated by showLocations)
            let hubAnnotations = hubs.map { MacSavedLocationAnnotation(hub: $0) }
            mapView.addAnnotations(hubAnnotations)

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
                renderer.strokeColor = .systemOrange
                renderer.lineWidth   = 3.5
                renderer.alpha       = 0.9
                return renderer
            }
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.strokeColor = NSColor(AppColors.primary).withAlphaComponent(0.7)
                renderer.fillColor   = NSColor(AppColors.primary).withAlphaComponent(0.08)
                renderer.lineWidth   = 1.5
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
                view.canShowCallout       = false   // handled by our own detail panel
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

            if let ann = annotation as? MacCustomPinAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "MacCustomPin", for: annotation
                )
                let opacity: CGFloat = ann.pin.isActive ? 1.0 : 0.30
                view.image                = Self.diamondImage(
                    color:   NSColor(ann.pin.type.color),
                    symbol:  ann.pin.type.sfSymbol,
                    opacity: opacity
                )
                view.centerOffset         = .zero  // diamond centered on coordinate
                view.canShowCallout       = false
                view.clusteringIdentifier = nil
                return view
            }

            if annotation is MacGhostPinAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "MacGhostPin", for: annotation
                )
                view.image          = Self.diamondImage(
                    color:   NSColor(Color.secondary),
                    symbol:  "mappin",
                    opacity: 0.50
                )
                view.centerOffset   = .zero
                view.canShowCallout = false
                view.clusteringIdentifier = nil
                return view
            }

            if annotation is MacSavedLocationAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "MacSavedLocationPin", for: annotation
                ) as! MKMarkerAnnotationView
                view.canShowCallout       = false
                view.markerTintColor      = NSColor(AppColors.primary)
                view.glyphImage           = NSImage(systemSymbolName: "mappin.circle.fill",
                                                    accessibilityDescription: nil)
                view.clusteringIdentifier = nil   // hubs never cluster
                return view
            }

            return nil
        }

        // MARK: Diamond image factory

        static func diamondImage(color: NSColor,
                                 symbol: String,
                                 size: CGFloat = 30,
                                 opacity: CGFloat = 1.0) -> NSImage {
            let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                // Diamond outline
                let half = size / 2 - 2
                let cx = rect.midX, cy = rect.midY
                let path = NSBezierPath()
                path.move(to: NSPoint(x: cx,        y: cy + half))
                path.line(to: NSPoint(x: cx + half, y: cy))
                path.line(to: NSPoint(x: cx,        y: cy - half))
                path.line(to: NSPoint(x: cx - half, y: cy))
                path.close()
                color.withAlphaComponent(opacity).setFill()
                NSColor.white.withAlphaComponent(opacity * 0.9).setStroke()
                path.lineWidth = 1.5
                path.fill()
                path.stroke()

                // SF Symbol glyph centered inside the diamond
                let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.35, weight: .medium)
                if let glyph = NSImage(systemSymbolName: symbol,
                                       accessibilityDescription: nil)?
                                    .withSymbolConfiguration(cfg) {
                    let gs = glyph.size
                    let origin = NSPoint(x: cx - gs.width / 2, y: cy - gs.height / 2)
                    NSGraphicsContext.current?.imageInterpolation = .high
                    glyph.draw(in: NSRect(origin: origin, size: gs),
                               from: .zero,
                               operation: .sourceOver,
                               fraction: opacity)
                }
                return true
            }
            return img
        }

        // MARK: MKMapViewDelegate — tap handling

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            defer { mapView.deselectAnnotation(view.annotation, animated: false) }

            if let ann = view.annotation as? MacLocationAnnotation {
                parent.onSelectSavedLocation?(ann.location)
                return
            }

            if let cluster = view.annotation as? MKClusterAnnotation {
                let members = cluster.memberAnnotations.compactMap { $0 as? MacEntryAnnotation }
                if members.count <= parent.clusterListMax {
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

            if let ann = view.annotation as? MacCustomPinAnnotation {
                parent.onSelectCustomPin?(ann.pin)
                return
            }

            if let ann = view.annotation as? MacSavedLocationAnnotation {
                parent.onSelectHub?(ann.hub)
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

/// Annotation wrapping a persisted CustomPin — rendered as a colored diamond.
final class MacCustomPinAnnotation: NSObject, MKAnnotation {
    let pin: CustomPin
    dynamic var coordinate: CLLocationCoordinate2D

    var title: String? { pin.displayName }

    init(pin: CustomPin) {
        self.pin        = pin
        self.coordinate = pin.coordinate
        super.init()
    }
}

final class MacSavedLocationAnnotation: NSObject, MKAnnotation {
    let hub: SavedLocation
    dynamic var coordinate: CLLocationCoordinate2D

    var title: String? { hub.name }

    init(hub: SavedLocation) {
        self.hub        = hub
        self.coordinate = hub.coordinate
        super.init()
    }
}

/// Temporary ghost annotation shown while the quick-add sheet is open.
final class MacGhostPinAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
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
                let km = trip.totalDistanceMeters / 1_000
                if km > 0 {
                    statCell(label: "Distance", value: String(format: "%.1f km", km))
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
        .background(Color(nsColor: .windowBackgroundColor))
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

// MARK: - SavedLocation strip (tab bar of saved locations at the top of the map)

private struct SavedLocationStrip: View {
    let locations:  [SavedLocation]
    let selectedID: UUID?
    var onSelect:   (UUID) -> Void

    var body: some View {
        // No ScrollView — NSScrollView on macOS intercepts taps before SwiftUI buttons
        // see them. Use a plain HStack + onTapGesture instead.
        HStack(spacing: 6) {
            ForEach(locations) { loc in
                let isSelected = selectedID == loc.id
                HStack(spacing: 4) {
                    if loc.isHub {
                        Image(systemName: "circle.dotted")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    Text(loc.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(isSelected ? .white : AppColors.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? AppColors.primary
                              : Color(nsColor: .windowBackgroundColor).opacity(0.88))
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                )
                .contentShape(Capsule())
                .onTapGesture { onSelect(loc.id) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Full map pane (used by MacRoot sidebar)

struct MacMapPane: View {
    var focusedTripID: UUID? = nil   // set by MacRoot when a trip row is tapped
    var externalPinID: UUID? = nil   // set by MacRoot when navigating from Pins list

    @EnvironmentObject private var store:              EntryStore
    @EnvironmentObject private var savedLocationStore:  SavedLocationStore
    @EnvironmentObject private var tripStore:           TripStore
    @EnvironmentObject private var customPinStore:      CustomPinStore

    @AppStorage("settings.clusterListMax")  private var clusterListMax: Int = 6

    // Layer visibility (persisted across restarts)
    @AppStorage("map.layer.entryPins")      private var showEntryPins:      Bool = true
    @AppStorage("map.layer.customPins")     private var showCustomPins:     Bool = true
    @AppStorage("map.layer.infrastructure") private var showInfrastructure: Bool = true
    @AppStorage("map.layer.wildlifeSigns")  private var showWildlifeSigns:  Bool = true
    @AppStorage("map.layer.terrain")        private var showTerrain:        Bool = true
    @AppStorage("map.layer.tripTracks")     private var showTripTracks:     Bool = true
    @AppStorage("map.layer.showInactive")   private var showInactivePins:   Bool = false

    @State private var showLocations    = true
    @State private var showTripPanel    = false
    @State private var showLayerPanel   = false
    @State private var importMessage:   String? = nil
    @State private var mapStyle:        MapStyle = .topo
    @State private var recenterTrigger  = false
    @State private var selectedTripID:  UUID?    = nil

    @State private var selectedEntryID: UUID?
    @State private var clusterEntries:  [TrailEntry] = []
    @State private var showClusterSheet = false

    // Custom-pin placement flow
    @State private var pendingPinCoord:  CLLocationCoordinate2D? = nil
    @State private var showQuickAddPin:  Bool = false
    // Custom-pin detail panel
    @State private var selectedPinID:   UUID? = nil
    // Saved-location detail panel
    @State private var selectedLocationID: UUID? = nil

    private var mappableEntries: [TrailEntry] {
        guard showEntryPins else { return [] }
        return store.entries.filter {
            !$0.isDraft && $0.latitude != nil && $0.longitude != nil
        }
    }

    private var visibleTrips: [Trip] {
        showTripTracks ? tripStore.trips : []
    }

    /// Entries within the location's radius (or 500 m for plain pins), sorted newest first.
    private func entriesNear(_ location: SavedLocation) -> [TrailEntry] {
        let searchRadius = location.radius ?? 500
        let loc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return store.entries
            .filter { e in
                guard !e.isDraft, let lat = e.latitude, let lon = e.longitude else { return false }
                return loc.distance(from: CLLocation(latitude: lat, longitude: lon)) <= searchRadius
            }
            .sorted { $0.date > $1.date }
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
            // Outer VStack: strip sits ABOVE the map so it is pure SwiftUI with no
            // NSView beneath it — the only reliable way to receive mouse events on macOS.
            VStack(spacing: 0) {
                if !savedLocationStore.locations.isEmpty {
                    SavedLocationStrip(
                        locations:  savedLocationStore.locations,
                        selectedID: selectedLocationID,
                        onSelect: { id in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedTripID = nil
                                selectedPinID  = nil
                                selectedLocationID = (selectedLocationID == id) ? nil : id
                            }
                        }
                    )
                }

            ZStack(alignment: .bottom) {
                MacMapView(
                    entries:            mappableEntries,
                    savedLocations:     savedLocationStore.locations,
                    showLocations:      showLocations,
                    trips:              visibleTrips,
                    tripEntryIDs:       tripAssociatedEntryIDs,
                    mapStyle:           mapStyle,
                    focusedTripID:      selectedTripID,
                    customPins:         customPinStore.pins,
                    showCustomPins:     showCustomPins,
                    showInfrastructure: showInfrastructure,
                    showWildlifeSigns:  showWildlifeSigns,
                    showTerrain:        showTerrain,
                    showInactivePins:   showInactivePins,
                    ghostPinCoord:      pendingPinCoord,
                    focusedPinID:       selectedPinID,
                    focusedLocationID:  selectedLocationID,
                    hubs:               savedLocationStore.locations.filter { $0.isHub },
                    onLongPress: { coord in
                        // Close any open panels before placing a new pin
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTripID = nil
                            selectedPinID  = nil
                        }
                        pendingPinCoord = coord
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showQuickAddPin = true
                        }
                    },
                    onSelectCustomPin: { pin in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTripID     = nil
                            selectedLocationID = nil
                            selectedPinID      = pin.id
                        }
                    },
                    onSelectSavedLocation: { loc in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTripID     = nil
                            selectedPinID      = nil
                            selectedLocationID = loc.id
                        }
                    },
                    onSelectHub: { hub in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if selectedLocationID == hub.id {
                                selectedLocationID = nil   // tap same hub again to deselect
                            } else {
                                selectedLocationID = hub.id
                                selectedTripID     = nil   // close trip panel if open
                                selectedPinID      = nil
                            }
                        }
                    },
                    recenterTrigger: $recenterTrigger,
                    clusterListMax:  clusterListMax,
                    onSelectEntry: { entry in
                        selectedEntryID = entry.id
                    },
                    onSelectCluster: { entries in
                        clusterEntries   = entries
                        showClusterSheet = true
                    }
                )
                .ignoresSafeArea(.container, edges: [.horizontal, .bottom])

                if mappableEntries.isEmpty && tripStore.trips.isEmpty
                   && customPinStore.pins.isEmpty {
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
                    .allowsHitTesting(false)
                }

                // Quick-add pin sheet — slides up from bottom
                if showQuickAddPin, let coord = pendingPinCoord {
                    MacQuickAddPinSheet(
                        coordinate: coord,
                        onPlace: { pin in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showQuickAddPin = false
                                pendingPinCoord = nil
                            }
                            customPinStore.add(pin)
                            // Immediately select the new pin to show its detail panel
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedPinID = pin.id
                            }
                        },
                        onCancel: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showQuickAddPin = false
                                pendingPinCoord = nil
                            }
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
                            .padding(.bottom, showQuickAddPin ? 180 : 20)
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.3), value: importMessage)
                }

            }  // end ZStack
            }  // end VStack

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

            // Saved-location detail panel
            if let locID = selectedLocationID,
               let loc = savedLocationStore.locations.first(where: { $0.id == locID }) {
                MacSavedLocationDetailPanel(
                    location: loc,
                    nearbyEntries: entriesNear(loc),
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.25)) { selectedLocationID = nil }
                    },
                    onSelectEntry: { entry in selectedEntryID = entry.id },
                    onDelete: loc.isHub ? {
                        withAnimation(.easeInOut(duration: 0.25)) { selectedLocationID = nil }
                        savedLocationStore.delete(id: loc.id)
                    } : nil
                )
                .frame(width: 280)
                .transition(.move(edge: .trailing))
            }

            // Custom pin detail panel
            if let pinID = selectedPinID,
               let pin = customPinStore.pins.first(where: { $0.id == pinID }) {
                MacCustomPinDetailPanel(
                    pin: pin,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.25)) { selectedPinID = nil }
                    },
                    onUpdate: { updated in
                        customPinStore.update(updated)
                    },
                    onDelete: { id in
                        withAnimation(.easeInOut(duration: 0.25)) { selectedPinID = nil }
                        customPinStore.delete(id: id)
                    }
                )
                .frame(width: 280)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTripID)
        .animation(.easeInOut(duration: 0.25), value: selectedPinID)
        .animation(.easeInOut(duration: 0.25), value: selectedLocationID)
        .onAppear {
            if let id = focusedTripID { selectedTripID = id }
            if let id = externalPinID { selectedPinID = id }
        }
        .onChange(of: externalPinID) { _, newID in
            if let id = newID {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTripID = nil
                    selectedPinID  = id
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {

                // Layers popover
                Button { showLayerPanel.toggle() } label: {
                    Label("Layers", systemImage: "square.3.layers.3d")
                }
                .help("Toggle map layers")
                .popover(isPresented: $showLayerPanel, arrowEdge: .top) {
                    MacLayerPanel()
                }

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
                                selectedPinID  = nil
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
#endif
