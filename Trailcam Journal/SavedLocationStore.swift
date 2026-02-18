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
        didSet { save() }
    }

    private let key = "saved_locations_v1"

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
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(locations)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            // intentionally silent for v1
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            locations = try JSONDecoder().decode([SavedLocation].self, from: data)
        } catch {
            locations = []
        }
    }
}
