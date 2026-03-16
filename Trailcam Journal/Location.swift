
//
//  Location.swift
//  Trailcam Journal
//
//  Unified named-location model that replaces the separate SavedLocation (plain
//  bookmark pin) and Hub (area with a geographic radius) types.
//
//  radius == nil  →  plain bookmark pin  (was SavedLocation)
//  radius != nil  →  area hub            (was Hub)
//
//  Backward-compat typealiases:
//    typealias SavedLocation = Location   (in SavedLocation.swift)
//    typealias Hub = Location             (in Hub.swift, macOS-only)
//

import Foundation
import CoreLocation

struct Location: Identifiable, Codable, Hashable {
    var id:        UUID    = UUID()
    var name:      String
    var latitude:  Double
    var longitude: Double
    /// Radius in metres. nil = plain bookmark pin, non-nil = area hub.
    var radius:    Double? = nil

    // MARK: - Convenience

    var isHub: Bool { radius != nil }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}
