import Foundation
import Combine
import SwiftUI

// Centralised UserDefaults key strings — prevents typo bugs.
enum StorageKeys {
    static let trailEntries = "trailEntries"
    static let savedLocations = "saved_locations_v1"
}

@MainActor
final class EntryStore: ObservableObject {
    private let storageKey = StorageKeys.trailEntries

    @Published var entries: [TrailEntry] = [] {
        didSet { scheduleSave() }
    }

    // Debounce: coalesce rapid successive writes (e.g. batch imports) into one.
    private var saveTask: Task<Void, Never>?

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

    /// Schedules a save after a short delay, cancelling any pending save.
    /// This prevents re-encoding the full array on every rapid change (e.g. batch import).
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 s
            guard !Task.isCancelled else { return }
            self?.persistNow()
        }
    }

    private func persistNow() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ EntryStore: failed to encode entries: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            entries = try JSONDecoder().decode([TrailEntry].self, from: data)
        } catch {
            print("❌ EntryStore: failed to decode saved entries: \(error)")
        }
    }
}
