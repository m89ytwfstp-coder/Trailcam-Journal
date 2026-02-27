import Foundation

enum ProjectSelfChecks {
    static func run() {
#if DEBUG
        verifyCanFinalizeRules()
        verifyStatsFilteringRules()
        verifyStatsTrendAndTimeOfDayRules()
#endif
    }

    private static func verifyCanFinalizeRules() {
        let base = TrailEntry(
            date: Date(),
            species: "Elg",
            camera: "Zeiss",
            notes: "",
            tags: [],
            photoFilename: nil,
            latitude: 63.4,
            longitude: 10.4,
            locationUnknown: false,
            isDraft: true,
            originalFilename: nil,
            photoAssetId: nil
        )

        var missingSpecies = base
        missingSpecies.species = nil
        assert(!missingSpecies.canFinalize, "Entry without species should not finalize.")

        var missingLocation = base
        missingLocation.latitude = nil
        missingLocation.longitude = nil
        assert(!missingLocation.canFinalize, "Entry without location should not finalize unless unknown.")

        var unknownLocation = base
        unknownLocation.latitude = nil
        unknownLocation.longitude = nil
        unknownLocation.locationUnknown = true
        assert(unknownLocation.canFinalize, "Entry with unknown location should be finalizable.")
    }

    private static func verifyStatsFilteringRules() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)

        let recent = TrailEntry(
            date: now,
            species: "Ulv",
            camera: "Zeiss",
            notes: "",
            tags: [],
            photoFilename: nil,
            latitude: nil,
            longitude: nil,
            locationUnknown: true,
            isDraft: false,
            originalFilename: nil,
            photoAssetId: nil
        )

        let old = TrailEntry(
            date: now.addingTimeInterval(-120 * 24 * 3600),
            species: "Hjort",
            camera: "Reolink",
            notes: "",
            tags: [],
            photoFilename: nil,
            latitude: nil,
            longitude: nil,
            locationUnknown: true,
            isDraft: false,
            originalFilename: nil,
            photoAssetId: nil
        )

        let draft = TrailEntry(
            date: now,
            species: "Jerv",
            camera: "Zeiss",
            notes: "",
            tags: [],
            photoFilename: nil,
            latitude: nil,
            longitude: nil,
            locationUnknown: true,
            isDraft: true,
            originalFilename: nil,
            photoAssetId: nil
        )

        let filtered = StatsHelpers.filterFinalEntries(
            [recent, old, draft],
            timeframe: .last30,
            selectedCamera: "Zeiss",
            now: now,
            calendar: calendar
        )

        assert(filtered.count == 1, "Stats filtering should remove drafts and non-matching timeframe/camera entries.")
    }

    private static func verifyStatsTrendAndTimeOfDayRules() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let now = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-02 00:00:00 UTC

        let dayEntry = TrailEntry(
            date: Date(timeIntervalSince1970: 1_704_088_800), // 2024-01-02 06:00:00 UTC
            species: "Elg",
            camera: "Zeiss",
            notes: "",
            tags: [],
            photoFilename: nil,
            latitude: nil,
            longitude: nil,
            locationUnknown: true,
            isDraft: false,
            originalFilename: nil,
            photoAssetId: nil
        )

        let nightEntry = TrailEntry(
            date: Date(timeIntervalSince1970: 1_704_135_600), // 2024-01-02 19:00:00 UTC
            species: "Ulv",
            camera: "Zeiss",
            notes: "",
            tags: [],
            photoFilename: nil,
            latitude: nil,
            longitude: nil,
            locationUnknown: true,
            isDraft: false,
            originalFilename: nil,
            photoAssetId: nil
        )

        let entries = [dayEntry, nightEntry]

        let daily = StatsHelpers.dailyCounts(lastDays: 7, entries: entries, now: now, calendar: calendar)
        assert(daily.count == 7, "Daily trend should emit one bucket per requested day.")
        assert(daily.reduce(0, { $0 + $1.count }) == 2, "Daily trend total should equal number of entries in range.")

        let uniqueDaily = StatsHelpers.uniqueSpeciesDailyCounts(lastDays: 7, entries: entries, now: now, calendar: calendar)
        assert(uniqueDaily.count == 7, "Unique-species daily trend should emit one bucket per requested day.")
        assert(uniqueDaily.reduce(0, { $0 + $1.count }) == 2, "Unique-species daily total should match unique species activity per day.")

        let histogram = StatsHelpers.hourHistogram(entries: entries, calendar: calendar)
        assert(histogram.count == 24, "Hour histogram must always contain 24 buckets.")
        assert(histogram[6] == 1 && histogram[19] == 1, "Hour histogram should increment the entry hour buckets.")

        let dayNight = StatsHelpers.dayNightCounts(entries: entries, calendar: calendar)
        assert(dayNight.day == 1 && dayNight.night == 1, "Day/night split should classify 06:00 as day and 19:00 as night.")
    }
}
