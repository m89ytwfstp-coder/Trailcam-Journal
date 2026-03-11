
//
//  HubStore.swift
//  Trailcam Journal
//
//  Persists Hub objects to JSON in Application Support, following the same
//  versioned StorageEnvelope pattern as TripStore and EntryStore.
//

#if os(macOS)
import Foundation
import Combine

@MainActor
final class HubStore: ObservableObject {

    private static let jsonFilename        = "hubs.json"
    private static let appSupportDir       = "TrailcamJournal"
    private static let currentSchemaVersion = 1

    private struct StorageEnvelope: Codable {
        let schemaVersion: Int
        let hubs: [Hub]
    }

    @Published var hubs: [Hub] = [] {
        didSet { save() }
    }

    init() { load() }

    // MARK: - Mutations

    func add(_ hub: Hub) {
        hubs.append(hub)
    }

    func update(_ hub: Hub) {
        guard let i = hubs.firstIndex(where: { $0.id == hub.id }) else { return }
        hubs[i] = hub
    }

    func delete(id: UUID) {
        hubs.removeAll { $0.id == id }
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
        let envelope = StorageEnvelope(schemaVersion: Self.currentSchemaVersion, hubs: hubs)
        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ HubStore save failed: \(error)")
        }
    }

    private func load() {
        guard let url  = dataFileURL(),
              let data = try? Data(contentsOf: url) else { return }
        if let envelope = try? JSONDecoder().decode(StorageEnvelope.self, from: data) {
            hubs = envelope.hubs
            return
        }
        if let legacy = try? JSONDecoder().decode([Hub].self, from: data) {
            hubs = legacy
            save()
        } else {
            print("❌ HubStore load failed")
        }
    }
}
#endif
