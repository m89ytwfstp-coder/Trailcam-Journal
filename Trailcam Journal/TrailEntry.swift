//
//  TrailEntry.swift
//  Trailcam Journal
//

import Foundation

// ── Entry type ────────────────────────────────────────────────────────────────

enum EntryType: String, Codable, CaseIterable {
    case sighting   = "sighting"    // Default — trailcam photo of a species
    case track      = "track"       // Physical sign: footprint, scat, scrape, rub
    case fieldNote  = "fieldNote"   // Text observation, no photo required

    var label: String {
        switch self {
        case .sighting:  "Sighting"
        case .track:     "Track"
        case .fieldNote: "Field Note"
        }
    }

    var symbol: String {
        switch self {
        case .sighting:  "camera.fill"
        case .track:     "pawprint.fill"
        case .fieldNote: "note.text"
        }
    }
}

// ── Trip model ─────────────────────────────────────────────────────────────────

struct Trip: Identifiable, Codable {
    var id:    UUID   = UUID()
    var name:  String
    var date:  Date
    var notes: String = ""
}

// ── Trail entry ────────────────────────────────────────────────────────────────

struct TrailEntry: Identifiable, Codable, Hashable {

    var id: UUID = UUID()

    // Core fields
    var date: Date

    // Draft-friendly: optional until finalized
    var species: String?          // required for .sighting; optional for .track; unused for .fieldNote
    var camera: String?           // optional
    var notes: String
    var tags: [String]

    // Image storage
    var photoFilename: String?
    var photoThumbnailFilename: String? = nil   // NEW — 400px thumbnail for Mac list views

    // Location
    var latitude: Double?
    var longitude: Double?
    var locationUnknown: Bool     // allows "final" even if no GPS/manual location

    // State
    var isDraft: Bool

    // Import metadata
    var originalFilename: String?
    var photoAssetId: String?     // local identifier from Photos (optional)

    // Entry type + trip (new — default values ensure backward-compat decoding)
    var entryType: EntryType = .sighting
    var tripID:    UUID?     = nil

    // ── Finalization rules (per entry type) ───────────────────────────────────
    var canFinalize: Bool {
        switch entryType {
        case .sighting:
            let hasSpecies  = (species?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            let hasLocation = locationUnknown || (latitude != nil && longitude != nil)
            return hasSpecies && hasLocation
        case .track:
            return locationUnknown || (latitude != nil && longitude != nil)
        case .fieldNote:
            return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // ── Display title (context-aware) ─────────────────────────────────────────
    var displayTitle: String {
        switch entryType {
        case .sighting:
            return species ?? "Unknown species"
        case .track:
            if let s = species, !s.isEmpty { return "\(s) track" }
            return "Animal track"
        case .fieldNote:
            let first = notes.components(separatedBy: "\n").first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return first.isEmpty ? "Field Note" : String(first.prefix(60))
        }
    }

    static func == (lhs: TrailEntry, rhs: TrailEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
