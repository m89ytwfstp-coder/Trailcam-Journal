//
//  MapLocationPickerView.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 18/12/2025.
//

import SwiftUI
import MapKit

struct MapLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var latitude: Double?
    @Binding var longitude: Double?

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 63.4305, longitude: 10.3951),
            span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
        )
    )

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    if let lat = latitude, let lon = longitude {
                        Marker("Selected", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    }
                }
                .onAppear {
                    // If an entry already has a location, start zoomed in on it
                    zoomToSelected()
                }
                .onChange(of: latitude) { _, _ in
                    zoomToSelected()
                }
                .onChange(of: longitude) { _, _ in
                    zoomToSelected()
                }

                .onTapGesture { location in
                    let point = CGPoint(x: location.x, y: location.y)
                    if let coordinate = proxy.convert(point, from: .local) {
                        latitude = coordinate.latitude
                        longitude = coordinate.longitude
                    }
                }

            }
            .navigationTitle("Pick location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(latitude == nil || longitude == nil)
                }
            }
        }
    }
    private func zoomToSelected() {
        guard let lat = latitude, let lon = longitude else { return }

        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02) // ~ zoom level
        position = .region(MKCoordinateRegion(center: center, span: span))
    }

}
