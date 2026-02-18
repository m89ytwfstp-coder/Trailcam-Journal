//
//  EntriesListView.swift
//  Trailcam Journal
//

import SwiftUI

struct EntriesListView: View {
    @EnvironmentObject var store: EntryStore
    @EnvironmentObject var savedLocationStore: SavedLocationStore

    @State private var searchText: String = ""

    // Delete confirmation
    @State private var pendingDelete: TrailEntry? = nil
    @State private var showDeleteConfirm: Bool = false

    private var finalizedEntries: [TrailEntry] {
        store.entries
            .filter { !$0.isDraft }
            .sorted { $0.date > $1.date }
    }

    private var filteredEntries: [TrailEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return finalizedEntries }

        return finalizedEntries.filter { entry in
            let species = (entry.species ?? "").lowercased()
            let camera = (entry.camera ?? "").lowercased()
            let notes  = entry.notes.lowercased()
            let loc    = locationLabel(for: entry).lowercased()
            return species.contains(q) || camera.contains(q) || notes.contains(q) || loc.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                AppHeader(
                    title: "Entries",
                    subtitle: "\(finalizedEntries.count) finalized observations"
                )

                TextField("Search species, location, notes…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                List {
                    ForEach(filteredEntries) { entry in
                        NavigationLink {
                            EntryDetailView(entryID: entry.id)
                        } label: {
                            EntryRow(entry: entry, locationText: locationLabel(for: entry))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                pendingDelete = entry
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .padding(.top, 2)
            .appScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Delete entry?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let id = pendingDelete?.id {
                    store.deleteEntry(id: id)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("This will permanently delete this entry.")
        }
    }

    private func locationLabel(for entry: TrailEntry) -> String {
        if entry.locationUnknown { return "Unknown location" }

        guard let lat = entry.latitude, let lon = entry.longitude else {
            return "No location"
        }

        let rLat = (lat * 10000).rounded() / 10000
        let rLon = (lon * 10000).rounded() / 10000

        if let match = savedLocationStore.locations.first(where: { loc in
            let lrLat = (loc.latitude * 10000).rounded() / 10000
            let lrLon = (loc.longitude * 10000).rounded() / 10000
            return lrLat == rLat && lrLon == rLon
        }) {
            return match.name
        }

        return String(format: "%.4f, %.4f", lat, lon)
    }
}

// MARK: - Row UI

private struct EntryRow: View {
    let entry: TrailEntry
    let locationText: String

    var body: some View {
        HStack(spacing: 12) {
            EntryPhotoView(entry: entry, height: 52, cornerRadius: 12, maxPixel: 200)
                .frame(width: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.species ?? "Unknown species")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                Text(locationText)
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}
