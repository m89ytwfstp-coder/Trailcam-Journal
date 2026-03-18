//
//  NestboxStore.swift
//  Trailcam Journal
//
//  Persists Nestbox objects (including embedded seasons + attempts)
//  to nestboxes.json in Application Support/TrailcamJournal/.
//
//  GPS photo linking: entries within 50 m of a nestbox's coordinate
//  are associated with that box. See nearbyEntries(for:in:).
//

import Foundation
import Combine
import CoreLocation

@MainActor
final class NestboxStore: ObservableObject {

    // MARK: - File names

    private static let jsonFilename  = "nestboxes.json"
    private static let appSupportDir = "TrailcamJournal"
    private static let schemaVersion = 1

    // MARK: - Storage envelope

    private struct StorageEnvelope: Codable {
        let schemaVersion: Int
        let nestboxes: [Nestbox]
    }

    // MARK: - Published state

    @Published var nestboxes: [Nestbox] = [] { didSet { save() } }

    // MARK: - Init

    init() { load() }

    // MARK: - Computed

    var activeBoxes: [Nestbox] { nestboxes.filter(\.isActive) }

    // MARK: - CRUD — Nestbox

    func add(_ box: Nestbox) {
        nestboxes.append(box)
    }

    func update(_ box: Nestbox) {
        guard let i = nestboxes.firstIndex(where: { $0.id == box.id }) else { return }
        nestboxes[i] = box
    }

    func delete(id: UUID) {
        nestboxes.removeAll { $0.id == id }
    }

    // MARK: - CRUD — Season

    func upsertSeason(_ season: NestboxSeason, in boxID: UUID) {
        guard let bi = nestboxes.firstIndex(where: { $0.id == boxID }) else { return }
        if let si = nestboxes[bi].seasons.firstIndex(where: { $0.id == season.id }) {
            nestboxes[bi].seasons[si] = season
        } else {
            nestboxes[bi].seasons.append(season)
        }
    }

    func deleteSeason(id seasonID: UUID, from boxID: UUID) {
        guard let bi = nestboxes.firstIndex(where: { $0.id == boxID }) else { return }
        nestboxes[bi].seasons.removeAll { $0.id == seasonID }
    }

    // MARK: - CRUD — Attempt

    func upsertAttempt(_ attempt: NestboxAttempt, seasonID: UUID, boxID: UUID) {
        guard let bi = nestboxes.firstIndex(where: { $0.id == boxID }),
              let si = nestboxes[bi].seasons.firstIndex(where: { $0.id == seasonID })
        else { return }

        if let ai = nestboxes[bi].seasons[si].attempts.firstIndex(where: { $0.id == attempt.id }) {
            nestboxes[bi].seasons[si].attempts[ai] = attempt
        } else {
            nestboxes[bi].seasons[si].attempts.append(attempt)
        }
    }

    func deleteAttempt(id attemptID: UUID, seasonID: UUID, boxID: UUID) {
        guard let bi = nestboxes.firstIndex(where: { $0.id == boxID }),
              let si = nestboxes[bi].seasons.firstIndex(where: { $0.id == seasonID })
        else { return }
        nestboxes[bi].seasons[si].attempts.removeAll { $0.id == attemptID }
    }

    // MARK: - GPS photo linking (Task 12)

    /// GPS proximity radius for linking entries to a nestbox (50 m).
    static let photoLinkRadiusMeters: Double = 50

    /// Returns entries from `allEntries` whose GPS coordinates fall within
    /// `photoLinkRadiusMeters` of `box`.
    func nearbyEntries(for box: Nestbox, in allEntries: [TrailEntry]) -> [TrailEntry] {
        guard let boxLoc = box.clLocation else { return [] }
        return allEntries.filter { entry in
            guard let lat = entry.latitude, let lon = entry.longitude else { return false }
            let entryLoc = CLLocation(latitude: lat, longitude: lon)
            return entryLoc.distance(from: boxLoc) <= Self.photoLinkRadiusMeters
        }
    }

    // MARK: - Persistence

    private func appSupportURL() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Self.appSupportDir, isDirectory: true)
    }

    private func dataFileURL() -> URL? {
        appSupportURL()?.appendingPathComponent(Self.jsonFilename)
    }

    private func ensureDirectory() {
        guard let dir = appSupportURL() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func save() {
        ensureDirectory()
        guard let url = dataFileURL() else { return }
        let envelope = StorageEnvelope(schemaVersion: Self.schemaVersion, nestboxes: nestboxes)
        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ NestboxStore save failed: \(error)")
        }
    }

    private func load() {
        guard let url  = dataFileURL(),
              let data = try? Data(contentsOf: url) else { return }
        if let envelope = try? JSONDecoder().decode(StorageEnvelope.self, from: data) {
            nestboxes = envelope.nestboxes
        } else if let legacy = try? JSONDecoder().decode([Nestbox].self, from: data) {
            nestboxes = legacy
            save()
            print("✅ NestboxStore: upgraded plain array to versioned envelope")
        } else {
            print("❌ NestboxStore load failed")
        }
    }
}
