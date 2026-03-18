//
//  ArrivalRecord.swift
//  Trailcam Journal
//
//  One first-arrival record per species per year.
//  ArrivalStore (arrivals.json) owns a flat array of these.
//

import Foundation

// MARK: - How the arrival was detected

enum ArrivalHow: String, Codable, CaseIterable, Identifiable {
    case seen     = "seen"
    case heard    = "heard"
    case trailcam = "trailcam"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .seen:     "Seen"
        case .heard:    "Heard"
        case .trailcam: "Trail Camera"
        }
    }

    var symbol: String {
        switch self {
        case .seen:     "eye"
        case .heard:    "ear"
        case .trailcam: "video"
        }
    }
}

// MARK: - Arrival record

struct ArrivalRecord: Identifiable, Codable, Hashable {
    var id:          UUID        = UUID()
    var species:     String                    // display name, e.g. "Gjøk"
    var year:        Int                       // calendar year, e.g. 2025
    var date:        Date                      // exact or approximate arrival date
    var how:         ArrivalHow  = .seen
    var approximate: Bool        = false       // true → date is only approximate
    var notes:       String      = ""

    /// Day-of-year (1–366), useful for cross-year comparison.
    var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
    }
}
