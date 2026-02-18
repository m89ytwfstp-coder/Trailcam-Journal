//
//  SavedLocation.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 08/01/2026.
//

import Foundation
import CoreLocation

struct SavedLocation: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double

    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}
