//
//  EntryFormatting.swift
//  Trailcam Journal
//
//  Shared formatting helpers for TrailEntry display.
//  Fixes issue #4: locationLabel was duplicated across EntriesListView and MacEntriesPane.
//

import Foundation

enum EntryFormatting {

    /// Returns a human-readable location label for an entry.
    /// Matches against saved locations using rounded coordinates (4 decimal places).
    static func locationLabel(for entry: TrailEntry, savedLocations: [SavedLocation]) -> String {
        if entry.locationUnknown { return "Unknown location" }

        guard let lat = entry.latitude, let lon = entry.longitude else {
            return "No location"
        }

        let rLat = (lat * 10000).rounded() / 10000
        let rLon = (lon * 10000).rounded() / 10000

        if let match = savedLocations.first(where: { loc in
            let lrLat = (loc.latitude * 10000).rounded() / 10000
            let lrLon = (loc.longitude * 10000).rounded() / 10000
            return lrLat == rLat && lrLon == rLon
        }) {
            return match.name
        }

        return String(format: "%.4f, %.4f", lat, lon)
    }
}
