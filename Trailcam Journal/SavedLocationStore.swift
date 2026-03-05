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
    @Published var locations: [SavedLocation] = [] {
        didSet { scheduleSave() }
    }

    private let key = StorageKeys.savedLocations

    // Debounce rapid successive writes.
    private var saveTask: Task<Void, Never>?

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
    }

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
            let data = try JSONEncoder().encode(locations)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("❌ SavedLocationStore: failed to encode locations: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            locations = try JSONDecoder().decode([SavedLocation].self, from: data)
        } catch {
            print("❌ SavedLocationStore: failed to decode locations: \(error)")
            locations = []
        }
    }
}
