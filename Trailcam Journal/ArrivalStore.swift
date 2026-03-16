//
//  ArrivalStore.swift
//  Trailcam Journal
//
//  Persists spring-arrival records (arrivals.json) and the per-user
//  watchlist (arrival_watchlist.json) in Application Support.
//
//  Default watchlist: 24 common Norwegian spring migrants / summer visitors.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ArrivalStore: ObservableObject {

    // MARK: - File names

    private static let recordsFilename   = "arrivals.json"
    private static let watchlistFilename = "arrival_watchlist.json"
    private static let appSupportDir     = "TrailcamJournal"
    private static let schemaVersion     = 1

    // MARK: - Storage envelopes

    private struct RecordsEnvelope: Codable {
        let schemaVersion: Int
        let records: [ArrivalRecord]
    }

    private struct WatchlistEnvelope: Codable {
        let schemaVersion: Int
        let species: [String]
    }

    // MARK: - Default watchlist

    static let defaultWatchlist: [String] = [
        "Bokfink",
        "Enkeltbekkasin",
        "Gransanger",
        "Grønnfink",
        "Gulspurv",
        "Gulsanger",
        "Gjøk",
        "Hagesanger",
        "Heipiplerke",
        "Jernspurv",
        "Linerle",
        "Løvsanger",
        "Låvesvale",
        "Munk",
        "Rugde",
        "Rødstjert",
        "Sivspurv",
        "Stær",
        "Taksvale",
        "Tornskate",
        "Trepiplerke",
        "Tårnseiler",
        "Varsler",
        "Vipe",
    ]

    // MARK: - Published state

    @Published var records:   [ArrivalRecord] = [] { didSet { saveRecords() } }
    @Published var watchlist: [String]        = [] { didSet { saveWatchlist() } }

    // MARK: - Init

    init() {
        loadRecords()
        loadWatchlist()
    }

    // MARK: - Computed helpers

    /// All calendar years that have at least one record, sorted descending.
    var years: [Int] {
        Array(Set(records.map(\.year))).sorted(by: >)
    }

    /// Records for a given species, sorted by date.
    func records(for species: String) -> [ArrivalRecord] {
        records.filter { $0.species == species }.sorted { $0.date < $1.date }
    }

    /// Earliest record for a species in a given year, or nil.
    func arrival(species: String, year: Int) -> ArrivalRecord? {
        records
            .filter { $0.species == species && $0.year == year }
            .min(by: { $0.date < $1.date })
    }

    // MARK: - Mutations — records

    func add(_ record: ArrivalRecord) {
        records.append(record)
    }

    func update(_ record: ArrivalRecord) {
        guard let i = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[i] = record
    }

    func delete(id: UUID) {
        records.removeAll { $0.id == id }
    }

    // MARK: - Mutations — watchlist

    func addToWatchlist(_ species: String) {
        let trimmed = species.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !watchlist.contains(trimmed) else { return }
        watchlist.append(trimmed)
        watchlist.sort()
    }

    func removeFromWatchlist(_ species: String) {
        watchlist.removeAll { $0 == species }
    }

    func removeFromWatchlist(at offsets: IndexSet) {
        watchlist.remove(atOffsets: offsets)
    }

    func resetWatchlistToDefault() {
        watchlist = Self.defaultWatchlist
    }

    // MARK: - Persistence helpers

    private func appSupportURL() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Self.appSupportDir, isDirectory: true)
    }

    private func ensureDirectory() {
        guard let dir = appSupportURL() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func url(for filename: String) -> URL? {
        appSupportURL()?.appendingPathComponent(filename)
    }

    // MARK: - Save

    private func saveRecords() {
        ensureDirectory()
        guard let url = url(for: Self.recordsFilename) else { return }
        let envelope = RecordsEnvelope(schemaVersion: Self.schemaVersion, records: records)
        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ ArrivalStore saveRecords failed: \(error)")
        }
    }

    private func saveWatchlist() {
        ensureDirectory()
        guard let url = url(for: Self.watchlistFilename) else { return }
        let envelope = WatchlistEnvelope(schemaVersion: Self.schemaVersion, species: watchlist)
        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ ArrivalStore saveWatchlist failed: \(error)")
        }
    }

    // MARK: - Load

    private func loadRecords() {
        guard let url  = url(for: Self.recordsFilename),
              let data = try? Data(contentsOf: url) else { return }
        if let envelope = try? JSONDecoder().decode(RecordsEnvelope.self, from: data) {
            records = envelope.records
        } else if let legacy = try? JSONDecoder().decode([ArrivalRecord].self, from: data) {
            records = legacy
            saveRecords()
        }
    }

    private func loadWatchlist() {
        guard let url  = url(for: Self.watchlistFilename),
              let data = try? Data(contentsOf: url) else {
            // First launch — seed with defaults
            watchlist = Self.defaultWatchlist
            return
        }
        if let envelope = try? JSONDecoder().decode(WatchlistEnvelope.self, from: data) {
            watchlist = envelope.species
        } else if let legacy = try? JSONDecoder().decode([String].self, from: data) {
            watchlist = legacy
            saveWatchlist()
        } else {
            watchlist = Self.defaultWatchlist
        }
    }
}
