//
//  SpeciesPhotoCache.swift
//  Trailcam Journal
//
//  Persists resolved photo URLs to disk so each species is only fetched once.
//  Thread-safe via a serial dispatch queue.
//

import Foundation

final class SpeciesPhotoCache {

    static let shared = SpeciesPhotoCache()

    private let queue = DispatchQueue(label: "SpeciesPhotoCache", qos: .utility)
    private var store: [String: String] = [:]   // speciesID -> urlString | "none"

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("TrailcamJournal", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir,
                                                  withIntermediateDirectories: true)
        return appDir.appendingPathComponent("species_photo_cache.json")
    }()

    private init() {
        load()
    }

    // MARK: - Public API

    /// Returns the cached URL string (may be "none") or nil if uncached.
    func cachedValue(for speciesID: String) -> String? {
        queue.sync { store[speciesID] }
    }

    /// Stores a URL string or "none" sentinel for a species ID.
    func set(_ value: String, for speciesID: String) {
        queue.async(flags: .barrier) {
            self.store[speciesID] = value
            self.persist()
        }
    }

    /// Removes all cached entries (e.g. from Settings > Reset Cache).
    func clearAll() {
        queue.async(flags: .barrier) {
            self.store = [:]
            self.persist()
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }
        store = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
