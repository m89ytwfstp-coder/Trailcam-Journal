//
//  TrailEntry.swift
//  Trailcam Journal
//

import Foundation
import CoreLocation

// ── Schema version history ────────────────────────────────────────────────────
// v1 (initial): base fields — date, species, camera, notes, tags, photoFilename,
//               photoThumbnailFilename, latitude, longitude, locationUnknown,
//               isDraft, originalFilename, photoAssetId, entryType, tripID
//
// v2 (2026-03): added customPinIDs: [UUID] — links entry to placed map pins
// ─────────────────────────────────────────────────────────────────────────────

// ── Entry type ────────────────────────────────────────────────────────────────

enum EntryType: String, Codable, CaseIterable {
    case sighting   = "sighting"    // Default — trailcam photo of a species
    case track      = "track"       // Physical sign: footprint, scat, scrape, rub
    case fieldNote  = "fieldNote"   // Text observation, no photo required
    case nestbox    = "nestbox"     // Nestbox observation / check

    var label: String {
        switch self {
        case .sighting:  "Trail Camera"
        case .track:     "Track"
        case .fieldNote: "Field Note"
        case .nestbox:   "Nestbox"
        }
    }

    var symbol: String {
        switch self {
        case .sighting:  "video.fill"
        case .track:     "pawprint.fill"
        case .fieldNote: "note.text"
        case .nestbox:   "house.fill"
        }
    }
}

// ── Trip model ─────────────────────────────────────────────────────────────────

struct Trip: Identifiable, Codable {
    var id:    UUID   = UUID()
    var name:  String
    var date:  Date
    var notes: String = ""

    // GPX track data (nil / empty for manually-created trips — backward-compatible defaults)
    var gpxFilename:  String?      = nil
    var trackPoints:  [TrackPoint] = []

    struct TrackPoint: Codable, Hashable {
        var latitude:  Double
        var longitude: Double
        var timestamp: Date?
        var elevation: Double?
    }

    // Derived — not persisted
    var startDate: Date? { trackPoints.compactMap(\.timestamp).min() }
    var endDate:   Date? { trackPoints.compactMap(\.timestamp).max() }

    /// Total track distance computed from consecutive trackPoints.
    var totalDistanceMeters: Double {
        guard trackPoints.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<trackPoints.count {
            let a = CLLocation(latitude: trackPoints[i-1].latitude, longitude: trackPoints[i-1].longitude)
            let b = CLLocation(latitude: trackPoints[i].latitude,   longitude: trackPoints[i].longitude)
            total += a.distance(from: b)
        }
        return total
    }
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

    // Custom map pin links (v2) — UUIDs of CustomPin objects linked to this entry
    var customPinIDs: [UUID] = []

    // Nestbox association — macOS only (nil = not linked to a nestbox)
    var nestboxID: UUID? = nil

    // Weather at time of logging — auto-fetched from met.no (nil = not yet fetched)
    var temperatureC:  Double? = nil
    var weatherSymbol: String? = nil   // met.no symbol code, e.g. "partlycloudy_day"
    var windSpeedMs:   Double? = nil

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
        case .nestbox:
            return nestboxID != nil
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
        case .nestbox:
            if let s = species, !s.isEmpty { return s }
            return "Nestbox check"
        }
    }

    static func == (lhs: TrailEntry, rhs: TrailEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
