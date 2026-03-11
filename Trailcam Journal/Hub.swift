
//
//  Hub.swift
//  Trailcam Journal
//
//  A Hub is a named map bookmark with a geographic centre and an association
//  radius. Entries whose GPS coordinates fall within that radius are
//  automatically surfaced in the hub's detail panel.
//

#if os(macOS)
import Foundation
import CoreLocation

struct Hub: Identifiable, Codable {
    var id:        UUID   = UUID()
    var name:      String
    var latitude:  Double
    var longitude: Double
    /// Radius in metres used to associate nearby entries. Default 10 km.
    var radius:    Double = 10_000

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}
#endif
