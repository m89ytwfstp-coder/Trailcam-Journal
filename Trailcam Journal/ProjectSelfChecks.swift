import Foundation

enum ProjectSelfChecks {
    static func run() {
#if DEBUG
        verifyCanFinalizeRules()
        verifyTrackFinalizationRules()
        verifyFieldNoteFinalizationRules()
        verifyNestboxFinalizationRules()
        verifyStatsFilteringRules()
#endif
    }

    private static func verifyCanFinalizeRules() {
        // ── .sighting (existing rules) ────────────────────────────────────────
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
            photoAssetId: nil,
            entryType: .sighting
        )

        var missingSpecies = base
        missingSpecies.species = nil
        assert(!missingSpecies.canFinalize, "Sighting without species should not finalize.")

        var missingLocation = base
        missingLocation.latitude = nil
        missingLocation.longitude = nil
        assert(!missingLocation.canFinalize, "Sighting without location should not finalize unless unknown.")

        var unknownLocation = base
        unknownLocation.latitude = nil
        unknownLocation.longitude = nil
        unknownLocation.locationUnknown = true
        assert(unknownLocation.canFinalize, "Sighting with unknown location should be finalizable.")
    }

    private static func verifyTrackFinalizationRules() {
        // ── .track rules ─────────────────────────────────────────────────────
        // track with valid GPS + no species should finalize
        let trackWithLocation = TrailEntry(
            date: Date(), species: nil, camera: nil, notes: "", tags: [],
            photoFilename: nil,
            latitude: 63.4, longitude: 10.4,
            locationUnknown: false, isDraft: true,
            originalFilename: nil, photoAssetId: nil,
            entryType: .track
        )
        assert(trackWithLocation.canFinalize,
               "Track with GPS location but no species should finalize.")

        // track with no location (and locationUnknown = false) should NOT finalize
        var trackNoLocation = trackWithLocation
        trackNoLocation.latitude  = nil
        trackNoLocation.longitude = nil
        assert(!trackNoLocation.canFinalize,
               "Track with no location and locationUnknown=false should not finalize.")

        // track with locationUnknown = true should finalize (no species needed)
        var trackUnknownLoc = trackNoLocation
        trackUnknownLoc.locationUnknown = true
        assert(trackUnknownLoc.canFinalize,
               "Track with locationUnknown=true should finalize regardless of species.")
    }

    private static func verifyFieldNoteFinalizationRules() {
        // ── .fieldNote rules ──────────────────────────────────────────────────
        // fieldNote with non-empty notes should finalize (no species/location needed)
        let noteWithText = TrailEntry(
            date: Date(), species: nil, camera: nil,
            notes: "Saw fresh tracks near the salt lick.",
            tags: [],
            photoFilename: nil,
            latitude: nil, longitude: nil,
            locationUnknown: false, isDraft: true,
            originalFilename: nil, photoAssetId: nil,
            entryType: .fieldNote
        )
        assert(noteWithText.canFinalize,
               "FieldNote with non-empty notes should finalize without species or location.")

        // fieldNote with empty notes should NOT finalize
        var noteEmpty = noteWithText
        noteEmpty.notes = "   "
        assert(!noteEmpty.canFinalize,
               "FieldNote with blank notes should not finalize.")
    }

    private static func verifyNestboxFinalizationRules() {
        // ── .nestbox rules ────────────────────────────────────────────────────
        let nestboxID = UUID()

        // nestbox entry with a nestboxID → should finalize (species/location optional)
        let nestboxWithBox = TrailEntry(
            date: Date(),
            species: nil,
            camera: nil,
            notes: "",
            tags: [],
            photoFilename: nil,
            latitude: nil,
            longitude: nil,
            locationUnknown: false,
            isDraft: true,
            originalFilename: nil,
            photoAssetId: nil,
            entryType: .nestbox,
            nestboxID: nestboxID
        )
        assert(nestboxWithBox.canFinalize,
               "Nestbox entry with a nestboxID should finalize without species or location.")

        // nestbox entry with no nestboxID → should NOT finalize
        var nestboxMissing = nestboxWithBox
        nestboxMissing.nestboxID = nil
        assert(!nestboxMissing.canFinalize,
               "Nestbox entry without a nestboxID should not finalize.")
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
