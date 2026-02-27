import Foundation

enum ProjectSelfChecks {
    static func run() {
#if DEBUG
        verifyCanFinalizeRules()
        verifyStatsFilteringRules()
        verifyStatsTrendAndTimeOfDayRules()
        #if os(macOS)
        verifyMacEntriesSearchSortRules()
        verifyMapFilteringRules()
        verifyMacEditorCoordinateRules()
        #endif
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

#if os(macOS)
    private static func verifyMacEntriesSearchSortRules() {
        let baseDate = Date(timeIntervalSince1970: 1_704_067_200)
        let elk = TrailEntry(
            date: baseDate,
            species: "Elg",
            camera: "A-Cam",
            notes: "River crossing",
            tags: [],
            photoFilename: nil,
            latitude: 60.1,
            longitude: 11.2,
            locationUnknown: false,
            isDraft: false,
            originalFilename: nil,
            photoAssetId: nil
        )
        let wolf = TrailEntry(
            date: baseDate.addingTimeInterval(100),
            species: "Ulv",
            camera: "Z-Cam",
            notes: "Forest edge",
            tags: [],
            photoFilename: nil,
            latitude: nil,
            longitude: nil,
            locationUnknown: true,
            isDraft: false,
            originalFilename: nil,
            photoAssetId: nil
        )

        let searched = MacEntriesPaneLogic.apply(
            entries: [elk, wolf],
            searchText: "forest",
            filterOption: .all,
            sortOption: .dateNewest,
            locationResolver: { $0.locationUnknown ? "Unknown location" : "Known location" }
        )
        assert(searched.count == 1 && searched.first?.species == "Ulv", "Entries search should include note text matches.")

        let sortedBySpecies = MacEntriesPaneLogic.apply(
            entries: [wolf, elk],
            searchText: "",
            filterOption: .all,
            sortOption: .species,
            locationResolver: { _ in "" }
        )
        assert(sortedBySpecies.first?.species == "Elg", "Entries sort should order by species when selected.")

        let tieA = TrailEntry(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA") ?? UUID(),
            date: baseDate,
            species: "Elg",
            camera: "Cam",
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
        let tieB = TrailEntry(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB") ?? UUID(),
            date: baseDate,
            species: "Elg",
            camera: "Cam",
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
        let tieSorted = MacEntriesPaneLogic.apply(
            entries: [tieB, tieA],
            searchText: "",
            filterOption: .all,
            sortOption: .species,
            locationResolver: { _ in "" }
        )
        assert(tieSorted.first?.id == tieA.id, "Entries sort tie-break should be deterministic for equal species.")

        assert(
            !MacEntriesPaneLogic.shouldClearSelection(selectedID: tieA.id, visibleIDs: [tieA.id, tieB.id]),
            "Selection should be retained when selected entry remains visible."
        )
        assert(
            MacEntriesPaneLogic.shouldClearSelection(selectedID: tieA.id, visibleIDs: [tieB.id]),
            "Selection should clear when selected entry is filtered out."
        )
    }

    private static func verifyMapFilteringRules() {
        let sharedDate = Date(timeIntervalSince1970: 1_704_067_200)
        let one = TrailEntry(date: sharedDate, species: "Elg", camera: "Cam-1", notes: "", tags: [], photoFilename: nil, latitude: 1, longitude: 1, locationUnknown: false, isDraft: false, originalFilename: nil, photoAssetId: nil)
        let two = TrailEntry(date: sharedDate, species: "Ulv", camera: "Cam-2", notes: "", tags: [], photoFilename: nil, latitude: 2, longitude: 2, locationUnknown: false, isDraft: false, originalFilename: nil, photoAssetId: nil)

        let filtered = MacMapPaneLogic.applyFilters(entries: [one, two], selectedSpecies: "Elg", selectedCamera: nil)
        assert(filtered.count == 1 && filtered.first?.species == "Elg", "Map filters should constrain entries by species.")
    }

    private static func verifyMacEditorCoordinateRules() {
        assert(MacEntryEditorLogic.parseCoordinate("63,42") == 63.42, "Editor coordinate parser should accept comma decimal values.")

        let canFinalize = MacEntryEditorLogic.canFinalize(
            species: "Elg",
            locationUnknown: false,
            latitudeText: "63.4",
            longitudeText: "10.4"
        )
        assert(canFinalize, "Editor finalize validation should succeed with species and valid coordinates.")
    }
#endif
}
