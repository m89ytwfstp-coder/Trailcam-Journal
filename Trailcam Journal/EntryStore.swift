import Foundation
import Combine
import SwiftUI

@MainActor
final class EntryStore: ObservableObject {
    private let storageKey = "trailEntries"

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
        // Only legacy entries store full JPEGs in Documents.
        if let filename = entry.photoFilename, !filename.isEmpty {
            ImageStorage.deleteJPEGFromDocuments(filename: filename)
        }
#endif
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            entries = try JSONDecoder().decode([TrailEntry].self, from: data)
        } catch {
            print("❌ Failed to decode saved entries: \(error)")
        }
    }
}
