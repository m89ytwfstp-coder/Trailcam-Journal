
//
//  LocationStore.swift
//  Trailcam Journal
//
//  Merged store for all named map locations — plain pins (radius == nil)
//  and area hubs (radius != nil).
//
//  On first launch it migrates from both legacy files:
//    • hubs.json          (former HubStore, macOS)
//    • savedLocations.json (former SavedLocationStore, all platforms)
//
//  Backward-compat typealiases:
//    typealias HubStore          = LocationStore   (Hub.swift,              macOS-only)
//    typealias SavedLocationStore = LocationStore   (SavedLocationStore.swift, all platforms)
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class LocationStore: ObservableObject {

    private static let jsonFilename        = "locations.json"
    private static let legacyHubsFilename  = "hubs.json"
    private static let legacyPinsFilename  = "savedLocations.json"
    private static let legacyUDKey         = "saved_locations_v1"
    private static let appSupportDir       = "TrailcamJournal"
    private static let currentSchemaVersion = 1

    // MARK: - Storage envelopes

    private struct Envelope: Codable {
        let schemaVersion: Int
        let locations: [Location]
    }

    // Legacy shapes for one-time migration
    private struct LegacyHubEnvelope: Codable {
        let schemaVersion: Int
        let hubs: [LegacyHub]
    }
    private struct LegacyHub: Codable {
        var id: UUID; var name: String
        var latitude: Double; var longitude: Double
        var radius: Double = 10_000
    }
    private struct LegacyPinEnvelope: Codable {
        let schemaVersion: Int
        let locations: [LegacyPin]
    }
    private struct LegacyPin: Codable {
        var id: UUID; var name: String
        var latitude: Double; var longitude: Double
    }

    // MARK: - Published state

    @Published var locations: [Location] = [] {
        didSet { save() }
    }

    // MARK: - Computed views

    /// Locations that have a radius — area hubs.
    var hubs: [Location] { locations.filter { $0.radius != nil } }

    /// Locations without a radius — plain bookmark pins.
    var pins: [Location] { locations.filter { $0.radius == nil } }

    // MARK: - Init

    init() { load() }

    // MARK: - Mutations

    func add(_ location: Location) {
        locations.append(location)
    }

    func update(_ location: Location) {
        guard let i = locations.firstIndex(where: { $0.id == location.id }) else { return }
        locations[i] = location
    }

    func delete(id: UUID) {
        locations.removeAll { $0.id == id }
    }

    /// Remove items at the given offsets within the full `locations` array.
    func remove(at offsets: IndexSet) {
        locations.remove(atOffsets: offsets)
    }

    /// Remove items at offsets relative to the `pins` sub-array only.
    /// Use this from ManageSavedLocationsView which iterates `pins`.
    func removePins(at offsets: IndexSet) {
        let ids = offsets.map { pins[$0].id }
        locations.removeAll { ids.contains($0.id) }
    }

    /// Remove all plain pins, leaving hubs intact.
    /// Used by SettingsView "Remove all saved locations" action.
    func clearAll() {
        locations = locations.filter { $0.radius != nil }
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

    private func legacyURL(_ filename: String) -> URL? {
        appSupportURL()?.appendingPathComponent(filename)
    }

    private func ensureDirectory() {
        guard let dir = appSupportURL() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func save() {
        ensureDirectory()
        guard let url = dataFileURL() else { return }
        let envelope = Envelope(schemaVersion: Self.currentSchemaVersion, locations: locations)
        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ LocationStore save failed: \(error)")
        }
    }

    private func load() {
        // 1. Try unified locations.json (happy path for existing users after first migration)
        if let url  = dataFileURL(),
           let data = try? Data(contentsOf: url),
           let env  = try? JSONDecoder().decode(Envelope.self, from: data) {
            locations = env.locations
            return
        }

        // 2. One-time migration from the two legacy stores
        var merged: [Location] = []
        merged += loadLegacyHubs()
        merged += loadLegacyPins()

        // 3. Fall back to very-old UserDefaults store
        if merged.isEmpty {
            if let data = UserDefaults.standard.data(forKey: Self.legacyUDKey),
               let legacy = try? JSONDecoder().decode([LegacyPin].self, from: data) {
                merged = legacy.map {
                    Location(id: $0.id, name: $0.name,
                             latitude: $0.latitude, longitude: $0.longitude)
                }
                UserDefaults.standard.removeObject(forKey: Self.legacyUDKey)
                print("✅ LocationStore: migrated \(merged.count) pins from UserDefaults")
            }
        }

        if !merged.isEmpty {
            locations = merged   // didSet → save() writes the new unified locations.json
            print("✅ LocationStore: merged \(merged.count) locations from legacy stores")
        }
    }

    private func loadLegacyHubs() -> [Location] {
        guard let url  = legacyURL(Self.legacyHubsFilename),
              let data = try? Data(contentsOf: url) else { return [] }
        if let env = try? JSONDecoder().decode(LegacyHubEnvelope.self, from: data) {
            return env.hubs.map {
                Location(id: $0.id, name: $0.name,
                         latitude: $0.latitude, longitude: $0.longitude,
                         radius: $0.radius)
            }
        }
        if let arr = try? JSONDecoder().decode([LegacyHub].self, from: data) {
            return arr.map {
                Location(id: $0.id, name: $0.name,
                         latitude: $0.latitude, longitude: $0.longitude,
                         radius: $0.radius)
            }
        }
        return []
    }

    private func loadLegacyPins() -> [Location] {
        guard let url  = legacyURL(Self.legacyPinsFilename),
              let data = try? Data(contentsOf: url) else { return [] }
        if let env = try? JSONDecoder().decode(LegacyPinEnvelope.self, from: data) {
            return env.locations.map {
                Location(id: $0.id, name: $0.name,
                         latitude: $0.latitude, longitude: $0.longitude)
            }
        }
        if let arr = try? JSONDecoder().decode([LegacyPin].self, from: data) {
            return arr.map {
                Location(id: $0.id, name: $0.name,
                         latitude: $0.latitude, longitude: $0.longitude)
            }
        }
        return []
    }
}
