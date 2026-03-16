import Foundation
import Combine
import SwiftUI

@MainActor
final class EntryStore: ObservableObject {

    // Issue #11: file-based persistence (replaces UserDefaults)
    private static let jsonFilename        = "trailEntries.json"
    private static let legacyUDKey         = "trailEntries"   // for one-time migration
    private static let appSupportDir       = "TrailcamJournal"
    private static let currentSchemaVersion = 2

    /// Versioned wrapper written to disk so future migrations know the source version.
    private struct StorageEnvelope: Codable {
        let schemaVersion: Int
        let entries: [TrailEntry]
    }

    @Published var entries: [TrailEntry] = [] {
        didSet { save() }
    }

    init() {
        load()
    }

    // MARK: - Deletion helpers

    func deleteEntry(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        cleanupEntry(entries[idx])
        entries.remove(at: idx)
    }

    func deleteEntries(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let toDelete = entries.filter { ids.contains($0.id) }
        toDelete.forEach(cleanupEntry)
        entries.removeAll(where: { ids.contains($0.id) })
    }

    func deleteAllDrafts() {
        let drafts = entries.filter { $0.isDraft }
        drafts.forEach(cleanupEntry)
        entries.removeAll(where: { $0.isDraft })
    }

    func deleteAllEntries() {
        entries.forEach(cleanupEntry)
        entries.removeAll()
    }

    private func cleanupEntry(_ entry: TrailEntry) {
#if os(iOS)
        if let f = entry.photoFilename,          !f.isEmpty { ImageStorage.deleteJPEGFromDocuments(filename: f) }
        if let f = entry.photoThumbnailFilename, !f.isEmpty { ImageStorage.deleteJPEGFromDocuments(filename: f) }
#elseif os(macOS)
        // Delete both the display image and the 400 px thumbnail (12d).
        if let f = entry.photoFilename,          !f.isEmpty { MacImageStore.deleteFile(filename: f) }
        if let f = entry.photoThumbnailFilename, !f.isEmpty { MacImageStore.deleteFile(filename: f) }
#endif
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
            entries: entries
        )
        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ EntryStore save failed: \(error)")
        }
    }

    private func load() {
        // 1. Try versioned envelope from file.
        if let url = dataFileURL(), let data = try? Data(contentsOf: url) {
            if let envelope = try? JSONDecoder().decode(StorageEnvelope.self, from: data) {
                entries = migrate(entries: envelope.entries, from: envelope.schemaVersion)
                return
            }
            // Fall back to pre-versioning plain array (written by earlier app builds).
            if let legacy = try? JSONDecoder().decode([TrailEntry].self, from: data) {
                entries = legacy
                save() // re-save in versioned format immediately
                print("✅ EntryStore: upgraded plain array to versioned envelope")
                return
            }
            print("❌ EntryStore: failed to decode file data")
        }

        // 2. One-time migration from UserDefaults (very old builds).
        if let data = UserDefaults.standard.data(forKey: Self.legacyUDKey) {
            if let legacy = try? JSONDecoder().decode([TrailEntry].self, from: data) {
                entries = legacy
                save()
                UserDefaults.standard.removeObject(forKey: Self.legacyUDKey)
                print("✅ EntryStore: migrated \(entries.count) entries from UserDefaults")
            } else {
                print("❌ EntryStore: UserDefaults migration failed")
            }
        }
    }

    /// Apply any schema transformations needed when loading older data.
    private func migrate(entries: [TrailEntry], from version: Int) -> [TrailEntry] {
        var result = entries
        if version < 2 {
            // v2: customPinIDs added — already defaults to [] via Codable,
            // so no field transformation needed. This block documents the migration
            // boundary and ensures schemaVersion is re-written correctly on next save.
            print("✅ EntryStore: migrated \(result.count) entries from schema v\(version) → v2")
        }
#if os(iOS)
        // Backfill thumbnails for entries that have a display image but no thumbnail yet.
        // This runs once per entry (idempotent) — thumbnail is generated from stored display file.
        result = result.map { entry in
            guard entry.photoThumbnailFilename == nil || entry.photoThumbnailFilename!.isEmpty,
                  let displayName = entry.photoFilename, !displayName.isEmpty,
                  let url  = ImageStorage.documentsDirectory()?.appendingPathComponent(displayName),
                  let data = try? Data(contentsOf: url),
                  let pair = ImageStorage.saveImagePair(data: data)
            else { return entry }
            var updated = entry
            updated.photoThumbnailFilename = pair.thumbnailFilename
            // pair.displayFilename is a duplicate — delete it to avoid orphan files
            ImageStorage.deleteJPEGFromDocuments(filename: pair.displayFilename)
            return updated
        }
#endif
        return result
    }
}
