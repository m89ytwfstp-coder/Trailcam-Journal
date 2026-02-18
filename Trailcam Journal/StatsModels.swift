//
//  StatsModels.swift
//  Trailcam Journal
//

import Foundation

enum StatsTimeframe: String, CaseIterable, Identifiable {
    case last7 = "Last 7 days"
    case last30 = "Last 30 days"
    case thisYear = "This year"
    case allTime = "All time"

    var id: String { rawValue }

    /// Lower-bound date used for filtering. `nil` means no lower bound.
    func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .last7:
            return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
        case .last30:
            return calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))
        case .thisYear:
            let comps = calendar.dateComponents([.year], from: now)
            return calendar.date(from: DateComponents(year: comps.year, month: 1, day: 1))
        case .allTime:
            return nil
        }
    }
}

struct StatsMetric {
    let entries: Int
    let activeDays: Int
    let uniqueSpecies: Int
    let uniqueLocations: Int
    let uniqueCameras: Int
}

struct StatsBarPoint: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}

struct RankedCount: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

enum TrendMode: String, CaseIterable, Identifiable {
    case entries = "Entries"
    case uniqueSpecies = "Unique species"

    var id: String { rawValue }
}

enum TimeOfDayMode: String, CaseIterable, Identifiable {
    case histogram24h = "24h"
    case dayNight = "Day/Night"

    var id: String { rawValue }
}
