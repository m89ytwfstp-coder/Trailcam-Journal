import Foundation

enum ProjectSelfChecks {
    static func run() {
#if DEBUG
        verifyCanFinalizeRules()
        verifyStatsFilteringRules()
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
}
