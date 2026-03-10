
//
//  TripStore.swift
//  Trailcam Journal
//
//  Persists Trip objects to JSON in Application Support, following the same
//  pattern as EntryStore.
//

import Foundation
import Combine

@MainActor
final class TripStore: ObservableObject {

    private static let jsonFilename         = "trips.json"
    private static let appSupportDir        = "TrailcamJournal"
    private static let currentSchemaVersion  = 1

    private struct StorageEnvelope: Codable {
        let schemaVersion: Int
        let trips: [Trip]
    }

    @Published var trips: [Trip] = [] {
        didSet { save() }
    }

    init() { load() }

    // MARK: - Mutations

    func add(_ trip: Trip) {
        trips.append(trip)
    }

    func update(_ trip: Trip) {
        guard let i = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[i] = trip
    }

    func delete(id: UUID) {
        trips.removeAll { $0.id == id }
    }

    // MARK: - Persistence

    private func dataFileURL() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Self.appSupportDir, isDirectory: true)
            .appendingPathComponent(Self.jsonFilename)
    }

    private func ensureDirectory() {
        guard let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Self.appSupportDir, isDirectory: true)
        else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func save() {
        ensureDirectory()
        guard let url = dataFileURL() else { return }
        let envelope = StorageEnvelope(schemaVersion: Self.currentSchemaVersion, trips: trips)
        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ TripStore save failed: \(error)")
        }
    }

    private func load() {
        guard let url  = dataFileURL(),
              let data = try? Data(contentsOf: url) else { return }
        if let envelope = try? JSONDecoder().decode(StorageEnvelope.self, from: data) {
            trips = migrate(trips: envelope.trips, from: envelope.schemaVersion)
            return
        }
        // Fall back to legacy plain array (written before versioning).
        if let legacy = try? JSONDecoder().decode([Trip].self, from: data) {
            trips = legacy
            save()
            print("✅ TripStore: upgraded plain array to versioned envelope")
        } else {
            print("❌ TripStore load failed")
        }
    }

    private func migrate(trips: [Trip], from version: Int) -> [Trip] {
        var result = trips
        // Future migrations: if version < 2 { ... }
        return result
    }
}
