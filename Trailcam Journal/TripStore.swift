
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

    private static let jsonFilename  = "trips.json"
    private static let appSupportDir = "TrailcamJournal"

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
        do {
            let data = try JSONEncoder().encode(trips)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ TripStore save failed: \(error)")
        }
    }

    private func load() {
        guard let url  = dataFileURL(),
              let data = try? Data(contentsOf: url) else { return }
        do {
            trips = try JSONDecoder().decode([Trip].self, from: data)
        } catch {
            print("❌ TripStore load failed: \(error)")
        }
    }
}
