
//
//  MacMapView.swift
//  Trailcam Journal
//
//  Issue #5: macOS Map view — Kartverket tiles + entry pin markers.
//

#if os(macOS)
import SwiftUI
import MapKit
import AppKit

// MARK: - NSViewRepresentable wrapper

struct MacMapView: NSViewRepresentable {
    let entries: [TrailEntry]
    var onSelectEntry: (TrailEntry) -> Void

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

        // Default region: Norway
        mapView.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 64.5, longitude: 17.0),
                span:   MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 15.0)
            ),
            animated: false
        )

        context.coordinator.syncAnnotations(with: entries)
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncAnnotations(with: entries)
    }

    // ──────────────────────────────────────────────────────────────
    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MacMapView
        weak var mapView: MKMapView?
        private var lastEntryIDs: Set<UUID> = []
        private var didFitOnce = false

        init(parent: MacMapView) { self.parent = parent }

        func syncAnnotations(with entries: [TrailEntry]) {
            guard let mapView else { return }
            let ids = Set(entries.map { $0.id })
            guard ids != lastEntryIDs else { return }
            lastEntryIDs = ids

            let existing = mapView.annotations.compactMap { $0 as? MacEntryAnnotation }
            mapView.removeAnnotations(existing)

            let annotations: [MacEntryAnnotation] = entries.compactMap { e in
                guard let lat = e.latitude, let lon = e.longitude,
                      lat != 0 || lon != 0 else { return nil }
                return MacEntryAnnotation(entry: e)
            }
            mapView.addAnnotations(annotations)

            // Fit all pins into view the first time entries appear
            if !annotations.isEmpty && !didFitOnce {
                didFitOnce = true
                mapView.showAnnotations(annotations, animated: false)
            }
        }

        // Kartverket tile renderer
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // Pin / cluster views
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "MacClusterPin", for: cluster
                ) as! MKMarkerAnnotationView
                view.canShowCallout = false
                view.markerTintColor = NSColor(AppColors.primary)
                view.glyphText  = "\(cluster.memberAnnotations.count)"
                view.glyphImage = nil
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
                // Zoom into cluster area
                let coords = cluster.memberAnnotations.map { $0.coordinate }
                mapView.setRegion(regionFitting(coords), animated: true)
                return
            }

            if let ann = view.annotation as? MacEntryAnnotation {
                parent.onSelectEntry(ann.entry)
            }
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

// ──────────────────────────────────────────────────────────────────
// MARK: - Annotation model (macOS-only copy; iOS uses EntryAnnotation)

final class MacEntryAnnotation: NSObject, MKAnnotation {
    let entry: TrailEntry
    dynamic var coordinate: CLLocationCoordinate2D

    var title: String?    { entry.species ?? "Unknown species" }
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

// ──────────────────────────────────────────────────────────────────
// MARK: - Full pane (used by MacRoot sidebar)

struct MacMapPane: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore

    @State private var selectedEntryID: UUID?

    private var mappableEntries: [TrailEntry] {
        store.entries.filter {
            !$0.isDraft && $0.latitude != nil && $0.longitude != nil
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MacMapView(entries: mappableEntries) { entry in
                selectedEntryID = entry.id
            }
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
        .sheet(isPresented: Binding(
            get: { selectedEntryID != nil },
            set: { if !$0 { selectedEntryID = nil } }
        )) {
            if let id = selectedEntryID {
                NavigationStack {
                    EntryDetailView(entryID: id)
                        .environmentObject(store)
                        .environmentObject(savedLocationStore)
                }
                .frame(minWidth: 480, minHeight: 560)
            }
        }
    }
}
#endif
