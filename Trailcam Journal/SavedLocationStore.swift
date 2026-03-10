//
//  SavedLocationStore.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 08/01/2026.
//

import Foundation
import Combine
import SwiftUI


final class SavedLocationStore: ObservableObject {

    // Issue #11: file-based persistence (replaces UserDefaults)
    private static let jsonFilename         = "savedLocations.json"
    private static let legacyUDKey          = "saved_locations_v1"
    private static let appSupportDir        = "TrailcamJournal"
    private static let currentSchemaVersion  = 1

    private struct StorageEnvelope: Codable {
        let schemaVersion: Int
        let locations: [SavedLocation]
    }

    @Published var locations: [SavedLocation] = [] {
        didSet { save() }
    }

    init() {
        load()
    }

    func add(_ location: SavedLocation) {
        locations.insert(location, at: 0)
    }

    func remove(at offsets: IndexSet) {
        locations.remove(atOffsets: offsets)
    }

    func clearAll() {
        locations.removeAll()
        // save() is triggered by didSet
    }

    // MARK: - Persistence (Issue #11: file-based JSON)

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
        let envelope = StorageEnvelope(
            schemaVersion: Self.currentSchemaVersion,
            locations: locations
        )
        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ SavedLocationStore save failed: \(error)")
        }
    }

    private func load() {
        // 1. Try versioned envelope from file.
        if let url = dataFileURL(), let data = try? Data(contentsOf: url) {
            if let envelope = try? JSONDecoder().decode(StorageEnvelope.self, from: data) {
                locations = migrate(locations: envelope.locations, from: envelope.schemaVersion)
                return
            }
            // Fall back to legacy plain array (written before versioning).
            if let legacy = try? JSONDecoder().decode([SavedLocation].self, from: data) {
                locations = legacy
                save()
                print("✅ SavedLocationStore: upgraded plain array to versioned envelope")
                return
            }
            print("❌ SavedLocationStore: failed to decode file data")
        }

        // 2. One-time migration from UserDefaults (very old builds).
        if let data = UserDefaults.standard.data(forKey: Self.legacyUDKey) {
            if let legacy = try? JSONDecoder().decode([SavedLocation].self, from: data) {
                locations = legacy
                save()
                UserDefaults.standard.removeObject(forKey: Self.legacyUDKey)
                print("✅ SavedLocationStore: migrated \(locations.count) locations from UserDefaults")
            } else {
                print("❌ SavedLocationStore: UserDefaults migration failed")
            }
        }
    }

    private func migrate(locations: [SavedLocation], from version: Int) -> [SavedLocation] {
        var result = locations
        // Future migrations: if version < 2 { ... }
        return result
    }
}
