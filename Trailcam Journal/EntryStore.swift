import Foundation
import Combine
import SwiftUI

@MainActor
final class EntryStore: ObservableObject {

    // Issue #11: file-based persistence (replaces UserDefaults)
    private static let jsonFilename  = "trailEntries.json"
    private static let legacyUDKey   = "trailEntries"      // for one-time migration
    private static let appSupportDir = "TrailcamJournal"

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
        guard let filename = entry.photoFilename, !filename.isEmpty else { return }
#if os(iOS)
        ImageStorage.deleteJPEGFromDocuments(filename: filename)
#elseif os(macOS)
        // Fix #2: macOS images are stored in Documents by MacImageStore — delete them too.
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename) {
            try? FileManager.default.removeItem(at: url)
        }
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
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ EntryStore save failed: \(error)")
        }
    }

    private func load() {
        // 1. Try file-based storage first.
        if let url = dataFileURL(), let data = try? Data(contentsOf: url) {
            do {
                entries = try JSONDecoder().decode([TrailEntry].self, from: data)
                return
            } catch {
                print("❌ EntryStore: failed to decode file — \(error)")
            }
        }

        // 2. One-time migration from UserDefaults.
        if let data = UserDefaults.standard.data(forKey: Self.legacyUDKey) {
            do {
                entries = try JSONDecoder().decode([TrailEntry].self, from: data)
                save()  // write to file
                UserDefaults.standard.removeObject(forKey: Self.legacyUDKey)
                print("✅ EntryStore: migrated \(entries.count) entries from UserDefaults to file storage")
            } catch {
                print("❌ EntryStore: UserDefaults migration failed — \(error)")
            }
        }
    }
}
