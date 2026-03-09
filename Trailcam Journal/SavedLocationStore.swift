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
    private static let jsonFilename  = "savedLocations.json"
    private static let legacyUDKey   = "saved_locations_v1"
    private static let appSupportDir = "TrailcamJournal"

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
        do {
            let data = try JSONEncoder().encode(locations)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ SavedLocationStore save failed: \(error)")
        }
    }

    private func load() {
        // 1. Try file-based storage first.
        if let url = dataFileURL(), let data = try? Data(contentsOf: url) {
            do {
                locations = try JSONDecoder().decode([SavedLocation].self, from: data)
                return
            } catch {
                print("❌ SavedLocationStore: failed to decode file — \(error)")
            }
        }

        // 2. One-time migration from UserDefaults.
        if let data = UserDefaults.standard.data(forKey: Self.legacyUDKey) {
            do {
                locations = try JSONDecoder().decode([SavedLocation].self, from: data)
                save()  // write to file
                UserDefaults.standard.removeObject(forKey: Self.legacyUDKey)
                print("✅ SavedLocationStore: migrated \(locations.count) locations from UserDefaults")
            } catch {
                print("❌ SavedLocationStore: UserDefaults migration failed — \(error)")
            }
        }
    }
}
