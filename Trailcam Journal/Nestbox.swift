//
//  Nestbox.swift
//  Trailcam Journal
//
//  Data model hierarchy for nestbox monitoring:
//   Nestbox          — the physical box (location, type, metadata)
//   NestboxSeason    — one monitoring season per box per year
//   NestboxAttempt   — one breeding attempt within a season
//   NestboxType      — box style / entrance hole
//   AttemptOutcome   — result of a breeding attempt
//

import Foundation
import CoreLocation

// MARK: - Box type

enum NestboxType: String, Codable, CaseIterable, Identifiable {
    case standard     = "standard"       // standard closed-front box
    case openFronted  = "open_fronted"   // open-fronted (robins, redstarts)
    case chimney      = "chimney"        // chimney / mandarin duck box
    case triangular   = "triangular"     // triangular / treecreeper wedge
    case bat          = "bat"            // bat box
    case other        = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard:    "Standard"
        case .openFronted: "Open-fronted"
        case .chimney:     "Chimney"
        case .triangular:  "Triangular"
        case .bat:         "Bat box"
        case .other:       "Other"
        }
    }

    var symbol: String {
        switch self {
        case .standard:    "house"
        case .openFronted: "house.lodge"
        case .chimney:     "building.columns"
        case .triangular:  "triangle"
        case .bat:         "moon.stars"
        case .other:       "square.dashed"
        }
    }
}

// MARK: - Attempt outcome

enum AttemptOutcome: String, Codable, CaseIterable, Identifiable {
    case unknown         = "unknown"
    case inProgress      = "in_progress"
    case successfulFledge = "successful_fledge"
    case partialFledge   = "partial_fledge"
    case abandoned       = "abandoned"
    case predated        = "predated"
    case failed          = "failed"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unknown:          "Unknown"
        case .inProgress:       "In progress"
        case .successfulFledge: "Successful fledge"
        case .partialFledge:    "Partial fledge"
        case .abandoned:        "Abandoned"
        case .predated:         "Predated"
        case .failed:           "Failed"
        }
    }

    var symbol: String {
        switch self {
        case .unknown:          "questionmark.circle"
        case .inProgress:       "clock"
        case .successfulFledge: "checkmark.circle.fill"
        case .partialFledge:    "checkmark.circle"
        case .abandoned:        "xmark.circle"
        case .predated:         "exclamationmark.triangle"
        case .failed:           "xmark.circle.fill"
        }
    }

    var isSuccess: Bool {
        self == .successfulFledge || self == .partialFledge
    }
}

// MARK: - Breeding attempt

struct NestboxAttempt: Identifiable, Codable, Hashable {
    var id:              UUID           = UUID()
    var species:         String         = ""        // e.g. "Rødstjert"
    var eggsLaid:        Int?           = nil
    var eggsHatched:     Int?           = nil
    var chicksFledged:   Int?           = nil
    var firstEggDate:    Date?          = nil
    var hatchDate:       Date?          = nil
    var fledgeDate:      Date?          = nil
    var outcome:         AttemptOutcome = .unknown
    var notes:           String         = ""
    var photos:          [String]       = []        // relative image filenames
}

// MARK: - Season (one year of monitoring)

struct NestboxSeason: Identifiable, Codable, Hashable {
    var id:        UUID              = UUID()
    var year:      Int
    var attempts:  [NestboxAttempt]  = []
    var notes:     String            = ""

    var totalEggsLaid:      Int { attempts.compactMap(\.eggsLaid).reduce(0, +) }
    var totalChicksFledged: Int { attempts.compactMap(\.chicksFledged).reduce(0, +) }
    var wasSuccessful:      Bool { attempts.contains { $0.outcome.isSuccess } }
}

// MARK: - Nestbox (the physical box)

struct Nestbox: Identifiable, Codable, Hashable {
    var id:              UUID         = UUID()
    var name:            String                         // short label, e.g. "Box 3"
    var boxType:         NestboxType  = .standard
    var latitude:        Double?      = nil
    var longitude:       Double?      = nil
    var entranceHoleMm:  Int?         = nil             // entrance hole diameter in mm
    var material:        String       = ""
    var facing:          String       = ""              // e.g. "N", "NE", "SE"
    var heightCm:        Int?         = nil             // mounting height in cm
    var installedYear:   Int?         = nil
    var isActive:        Bool         = true
    var notes:           String       = ""
    var coverPhotoName:  String?      = nil             // filename in MacImageStore dir
    var seasons:         [NestboxSeason] = []

    // MARK: Computed

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var clLocation: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    /// Most-recent season with data.
    var latestSeason: NestboxSeason? {
        seasons.max(by: { $0.year < $1.year })
    }

    /// Total fledglings across all recorded seasons.
    var allTimeFledglings: Int {
        seasons.map(\.totalChicksFledged).reduce(0, +)
    }

    /// Season for a given year, or nil.
    func season(for year: Int) -> NestboxSeason? {
        seasons.first { $0.year == year }
    }
}
