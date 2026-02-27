//
//  MapLocationPickerInLine.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 16/01/2026.
//

import SwiftUI
import MapKit

struct MapLocationPickerInline: UIViewRepresentable {
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    private let defaultCenter = CLLocationCoordinate2D(latitude: 63.4305, longitude: 10.3951) // Trondheim
    private let defaultSpan = MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
    private let selectedSpan = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false

        // Tap to set coordinate
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)

        // Start region (Trondheim)
        mapView.setRegion(
            MKCoordinateRegion(center: defaultCenter, span: defaultSpan),
            animated: false
        )

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing pins
        mapView.removeAnnotations(mapView.annotations)

        if let lat = latitude, let lon = longitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)

            let ann = MKPointAnnotation()
            ann.coordinate = coord
            ann.title = "Selected"
            mapView.addAnnotation(ann)

            let shouldRecenter =
                context.coordinator.lastCenteredCoordinate == nil ||
                abs((context.coordinator.lastCenteredCoordinate?.latitude ?? 0) - coord.latitude) > 0.000_001 ||
                abs((context.coordinator.lastCenteredCoordinate?.longitude ?? 0) - coord.longitude) > 0.000_001

            if shouldRecenter {
                let region = MKCoordinateRegion(center: coord, span: selectedSpan)
                mapView.setRegion(region, animated: true)
                context.coordinator.lastCenteredCoordinate = coord
                context.coordinator.didSetDefaultRegion = true
            }
        } else {
            // No coordinate: set default only once.
            if !context.coordinator.didSetDefaultRegion {
                let region = MKCoordinateRegion(center: defaultCenter, span: defaultSpan)
                mapView.setRegion(region, animated: false)
                context.coordinator.didSetDefaultRegion = true
            }
            context.coordinator.lastCenteredCoordinate = nil
        }
    }

    final class Coordinator: NSObject {
        var parent: MapLocationPickerInline
        var didSetDefaultRegion: Bool = false
        var lastCenteredCoordinate: CLLocationCoordinate2D?

        init(_ parent: MapLocationPickerInline) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coord = mapView.convert(point, toCoordinateFrom: mapView)

            parent.latitude = coord.latitude
            parent.longitude = coord.longitude
        }
    }
}
