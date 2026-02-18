//
//  TrailEntry.swift
//  Trailcam Journal
//

import Foundation

struct TrailEntry: Identifiable, Codable, Hashable {

    var id: UUID = UUID()

    // Core fields
    var date: Date

    // Draft-friendly: optional until finalized
    var species: String?          // required to finalize
    var camera: String?           // optional (can be missing)
    var notes: String
    var tags: [String]

    // Image storage
    var photoFilename: String?

    // Location
    var latitude: Double?
    var longitude: Double?
    var locationUnknown: Bool     // allows “final” even if no GPS/manual location

    // State
    var isDraft: Bool             // ✅ the key change

    // Import metadata (nice to have)
    var originalFilename: String?
    var photoAssetId: String?     // local identifier from Photos (optional)

    // Helper: is this entry ready to finalize?
    var canFinalize: Bool {
        let hasSpecies = (species?.isEmpty == false)
        let hasLocation = locationUnknown || (latitude != nil && longitude != nil)
        return hasSpecies && hasLocation
    }
    static func == (lhs: TrailEntry, rhs: TrailEntry) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
