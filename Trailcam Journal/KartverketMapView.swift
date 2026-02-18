//
//  KartverketMapView.swift
//  Trailcam Journal
//

import SwiftUI
import MapKit
import UIKit

final class EntryAnnotation: NSObject, MKAnnotation {
    let entry: TrailEntry
    dynamic var coordinate: CLLocationCoordinate2D

    var title: String? { entry.species ?? "Unknown species" }
    var subtitle: String? { entry.date.formatted(date: .abbreviated, time: .shortened) }

    init(entry: TrailEntry) {
        self.entry = entry
        self.coordinate = CLLocationCoordinate2D(latitude: entry.latitude ?? 0, longitude: entry.longitude ?? 0)
        super.init()
    }
}

struct KartverketMapView: UIViewRepresentable {
    let entries: [TrailEntry]

    @Binding var region: MKCoordinateRegion
    @Binding var mapCenter: CLLocationCoordinate2D

    var onSelectEntry: (TrailEntry) -> Void
    var onSelectCluster: ([TrailEntry]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView

        // Base map tiles
        let overlay = KartverketTileOverlay(layer: .topo)
        mapView.addOverlay(overlay, level: .aboveLabels)

        // Clustering enabled (standard MapKit)
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "EntryPin")
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "ClusterPin")

        mapView.setRegion(region, animated: false)

        // Initial annotations
        context.coordinator.syncAnnotations(with: entries)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Keep coordinator in sync with latest closures/bindings
        context.coordinator.parent = self

        // Update region if changed by SwiftUI
        if !context.coordinator.isUserInteracting {
            mapView.setRegion(region, animated: true)
        }

        // Keep mapCenter updated while user pans
        mapCenter = mapView.centerCoordinate

        // Refresh annotations when entries change
        context.coordinator.syncAnnotations(with: entries)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: KartverketMapView
        weak var mapView: MKMapView?

        var isUserInteracting: Bool = false
        private var lastEntryIDs: Set<UUID> = []

        init(parent: KartverketMapView) {
            self.parent = parent
        }

        func syncAnnotations(with entries: [TrailEntry]) {
            guard let mapView else { return }

            let ids = Set(entries.map { $0.id })
            guard ids != lastEntryIDs else { return }
            lastEntryIDs = ids

            // Remove existing EntryAnnotation only (keep user location etc.)
            let existing = mapView.annotations.compactMap { $0 as? EntryAnnotation }
            mapView.removeAnnotations(existing)

            // Add new
            let annotations: [EntryAnnotation] = entries.compactMap { e in
                guard let lat = e.latitude, let lon = e.longitude else { return nil }
                guard lat != 0 || lon != 0 else { return nil }
                return EntryAnnotation(entry: e)
            }

            mapView.addAnnotations(annotations)
        }

        // MARK: Region interaction tracking (so SwiftUI doesn't fight user)
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            isUserInteracting = true
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            isUserInteracting = false
            parent.mapCenter = mapView.centerCoordinate
            parent.region = mapView.region
        }

        // MARK: Overlays (Kartverket tiles)
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: Pin views (✅ regular markers)
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            // Cluster marker
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "ClusterPin", for: cluster) as! MKMarkerAnnotationView
                view.canShowCallout = false
                view.markerTintColor = UIColor(AppColors.primary)

                // Show count
                view.glyphText = "\(cluster.memberAnnotations.count)"
                view.glyphImage = nil

                return view
            }

            // Single entry marker
            if annotation is EntryAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "EntryPin", for: annotation) as! MKMarkerAnnotationView
                view.canShowCallout = false
                view.markerTintColor = UIColor(AppColors.primary.opacity(0.95))

                // Standard marker, no thumbnail
                view.glyphImage = nil
                view.glyphText = nil

                // Enable clustering
                view.clusteringIdentifier = "trailEntry"

                return view
            }

            return nil
        }

        // MARK: Tap handling
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            defer { mapView.deselectAnnotation(view.annotation, animated: false) }

            if let cluster = view.annotation as? MKClusterAnnotation {
                let memberEntries: [TrailEntry] = cluster.memberAnnotations.compactMap { ann in
                    (ann as? EntryAnnotation)?.entry
                }
                parent.onSelectCluster(memberEntries)
                return
            }

            if let entryAnn = view.annotation as? EntryAnnotation {
                parent.onSelectEntry(entryAnn.entry)
                return
            }
        }
    }
}
