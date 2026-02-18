//
//  StatsHelpers.swift
//  Trailcam Journal
//

import Foundation

enum StatsHelpers {

    // MARK: - Filtering

    static func filterFinalEntries(
        _ entries: [TrailEntry],
        timeframe: StatsTimeframe,
        selectedCamera: String?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TrailEntry] {
        let finals = entries.filter { !$0.isDraft }

        let start = timeframe.startDate(now: now, calendar: calendar)
        let cameraFiltered = finals.filter { entry in
            if let selectedCamera, !selectedCamera.isEmpty {
                return (entry.camera ?? "") == selectedCamera
            }
            return true
        }

        guard let start else { return cameraFiltered }
        return cameraFiltered.filter { $0.date >= start }
    }

    // MARK: - Overview metrics

    static func metrics(from entries: [TrailEntry], calendar: Calendar = .current) -> StatsMetric {
        let entriesCount = entries.count

        let activeDays = Set(entries.map { calendar.startOfDay(for: $0.date) }).count

        let speciesNames = entries
            .compactMap { $0.species?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let uniqueSpecies = Set(speciesNames).count

        let cameraNames = entries
            .compactMap { $0.camera?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let uniqueCameras = Set(cameraNames).count

        // GPS locations only, rounded to ~100m to avoid near-duplicates
        let roundedLocations = entries.compactMap { e -> String? in
            guard let lat = e.latitude, let lon = e.longitude else { return nil }
            let rLat = (lat * 1000).rounded() / 1000
            let rLon = (lon * 1000).rounded() / 1000
            return "\(rLat),\(rLon)"
        }
        let uniqueLocations = Set(roundedLocations).count

        return StatsMetric(
            entries: entriesCount,
            activeDays: activeDays,
            uniqueSpecies: uniqueSpecies,
            uniqueLocations: uniqueLocations,
            uniqueCameras: uniqueCameras
        )
    }

    // MARK: - Trend

    static func dailyCounts(lastDays: Int, entries: [TrailEntry], now: Date = Date(), calendar: Calendar = .current) -> [StatsBarPoint] {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(lastDays - 1), to: end) ?? end

        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.count }

        return (0..<lastDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return StatsBarPoint(date: day, count: byDay[day, default: 0])
        }
    }

    static func weeklyCounts(lastWeeks: Int, entries: [TrailEntry], now: Date = Date(), calendar: Calendar = .current) -> [StatsBarPoint] {
        // ISO-like week buckets (startOfWeek)
        let endWeek = startOfWeek(for: now, calendar: calendar)
        let startWeek = calendar.date(byAdding: .weekOfYear, value: -(lastWeeks - 1), to: endWeek) ?? endWeek

        let byWeek = Dictionary(grouping: entries) { startOfWeek(for: $0.date, calendar: calendar) }
            .mapValues { $0.count }

        return (0..<lastWeeks).compactMap { offset in
            guard let week = calendar.date(byAdding: .weekOfYear, value: offset, to: startWeek) else { return nil }
            return StatsBarPoint(date: week, count: byWeek[week, default: 0])
        }
    }

    static func monthlyCounts(year: Int, entries: [TrailEntry], calendar: Calendar = .current) -> [StatsBarPoint] {
        let months = Array(1...12)

        let byMonth = Dictionary(grouping: entries) { entry -> Date in
            let comps = calendar.dateComponents([.year, .month], from: entry.date)
            return calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) ?? entry.date
        }
        .mapValues { $0.count }

        return months.compactMap { m in
            let d = calendar.date(from: DateComponents(year: year, month: m, day: 1))
            guard let d else { return nil }
            return StatsBarPoint(date: d, count: byMonth[d, default: 0])
        }
    }

    static func uniqueSpeciesDailyCounts(lastDays: Int, entries: [TrailEntry], now: Date = Date(), calendar: Calendar = .current) -> [StatsBarPoint] {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(lastDays - 1), to: end) ?? end

        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
            .mapValues { dayEntries in
                Set(dayEntries.compactMap { $0.species?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }).count
            }

        return (0..<lastDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return StatsBarPoint(date: day, count: byDay[day, default: 0])
        }
    }

    static func uniqueSpeciesMonthlyCounts(year: Int, entries: [TrailEntry], calendar: Calendar = .current) -> [StatsBarPoint] {
        let months = Array(1...12)

        let byMonth = Dictionary(grouping: entries) { entry -> Date in
            let comps = calendar.dateComponents([.year, .month], from: entry.date)
            return calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) ?? entry.date
        }
        .mapValues { monthEntries in
            Set(monthEntries.compactMap { $0.species?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }).count
        }

        return months.compactMap { m in
            let d = calendar.date(from: DateComponents(year: year, month: m, day: 1))
            guard let d else { return nil }
            return StatsBarPoint(date: d, count: byMonth[d, default: 0])
        }
    }

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    // MARK: - Rankings

    static func topSpecies(entries: [TrailEntry], limit: Int = 5) -> [RankedCount] {
        let counts = entries.reduce(into: [String: Int]()) { dict, e in
            let s = (e.species ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { return }
            dict[s, default: 0] += 1
        }
        return counts
            .map { RankedCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }

    static func allSpeciesRanking(entries: [TrailEntry]) -> [RankedCount] {
        let counts = entries.reduce(into: [String: Int]()) { dict, e in
            let s = (e.species ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { return }
            dict[s, default: 0] += 1
        }
        return counts
            .map { RankedCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    static func topCameras(entries: [TrailEntry], limit: Int = 3) -> [RankedCount] {
        let counts = entries.reduce(into: [String: Int]()) { dict, e in
            let c = (e.camera ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !c.isEmpty else { return }
            dict[c, default: 0] += 1
        }
        return counts
            .map { RankedCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }

    static func allCameraRanking(entries: [TrailEntry]) -> [RankedCount] {
        let counts = entries.reduce(into: [String: Int]()) { dict, e in
            let c = (e.camera ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !c.isEmpty else { return }
            dict[c, default: 0] += 1
        }
        return counts
            .map { RankedCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Time of day

    static func hourHistogram(entries: [TrailEntry], calendar: Calendar = .current) -> [Int] {
        var buckets = Array(repeating: 0, count: 24)
        for e in entries {
            let h = calendar.component(.hour, from: e.date)
            if (0..<24).contains(h) { buckets[h] += 1 }
        }
        return buckets
    }

    static func dayNightCounts(entries: [TrailEntry], calendar: Calendar = .current) -> (day: Int, night: Int) {
        // Simple split: Day 06-18, Night 18-06
        var day = 0
        var night = 0
        for e in entries {
            let h = calendar.component(.hour, from: e.date)
            if (6..<18).contains(h) { day += 1 } else { night += 1 }
        }
        return (day, night)
    }
}
