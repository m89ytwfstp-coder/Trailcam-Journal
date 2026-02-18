//
//  CameraEntriesView.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 23/12/2025.
//

import SwiftUI

struct CameraEntriesView: View {
    let camera: String
    @EnvironmentObject private var store: EntryStore

    private var entries: [TrailEntry] {
        store.entries
            .filter { $0.camera == camera }
            .sorted { $0.date > $1.date }
    }
    private var entryCount: Int {
        entries.count
    }

    private var uniqueSpeciesCount: Int {
        Set(entries.map(\.species)).count
    }

    private var newestDate: Date? {
        entries.first?.date
    }

    private var oldestDate: Date? {
        entries.last?.date
    }
    
    private var topSpecies: (name: String, count: Int)? {
        let counts = Dictionary(
            grouping: entries.compactMap { $0.species },
            by: { $0 }
        )
        .mapValues { $0.count }

        guard let best = counts.max(by: { $0.value < $1.value }) else {
            return nil
        }

        return (best.key, best.value)
    }



    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(entryCount) entries")
                            .font(.headline)

                        Text("\(uniqueSpeciesCount) species")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        if let topSpecies {
                            Text("Top: \(topSpecies.name) (\(topSpecies.count))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if let newestDate {
                            Text("Last")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(newestDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                        }

                        if let oldestDate {
                            Text("First")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(oldestDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Entries") {
                ForEach(entries) { entry in
                    NavigationLink {
                        EntryDetailView(entryID: entry.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.species ?? "Unknown species")
                                .font(.headline)

                            if let camera = entry.camera, !camera.isEmpty {
                                Text(camera)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                    }
                }
            }
        }

        .navigationTitle(camera)
    }
}
