//
//  BucketListLogic.swift
//  Trailcam Journal
//

import Foundation

enum BucketListLogic {

    /// Returns a dictionary: speciesID -> earliest sighting date.
    /// IMPORTANT: This is computed from real entries and is never stored.
    ///
    /// Current app state:
    /// - TrailEntry.species is a Norwegian display name (String?)
    /// - SpeciesCatalog uses stable IDs
    ///
    /// So we map entry.species (nameNO) -> species.id, then compute earliest date.
    static func firstSightingBySpeciesID(from entries: [TrailEntry]) -> [String: Date] {
        // Build lookup: "Jerv" -> "wolverine"
        let nameToID: [String: String] = Dictionary(
            uniqueKeysWithValues: SpeciesCatalog.all.map { ($0.nameNO, $0.id) }
        )

        var firstByID: [String: Date] = [:]

        for e in entries {
            // Ignore drafts in stats
            guard e.isDraft == false else { continue }

            // Must have a species name (for now)
            guard let name = e.species?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { continue }

            // Convert name -> speciesID
            guard let speciesID = nameToID[name] else { continue }

            if let existing = firstByID[speciesID] {
                if e.date < existing { firstByID[speciesID] = e.date }
            } else {
                firstByID[speciesID] = e.date
            }
        }

        return firstByID
    }
}
