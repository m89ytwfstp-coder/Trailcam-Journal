//
//  EntriesListView.swift
//  Trailcam Journal
//

import SwiftUI

struct EntriesListView: View {
    @EnvironmentObject var store: EntryStore
    @EnvironmentObject var savedLocationStore: SavedLocationStore

    @State private var searchText: String = ""
    @State private var selectedTag: String? = nil

    // Delete confirmation
    @State private var pendingDelete: TrailEntry? = nil
    @State private var showDeleteConfirm: Bool = false

    private var finalizedEntries: [TrailEntry] {
        store.entries
            .filter { !$0.isDraft }
            .sorted { $0.date > $1.date }
    }

    /// All unique tags across finalized entries, sorted alphabetically.
    private var allTags: [String] {
        Array(
            finalizedEntries
                .flatMap { $0.tags }
                .reduce(into: Set<String>()) { $0.insert($1) }
        ).sorted()
    }

    private var filteredEntries: [TrailEntry] {
        var result = finalizedEntries

        // Tag chip filter
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        // Text search (also matches tags)
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { entry in
                let species = (entry.species ?? "").lowercased()
                let camera  = (entry.camera ?? "").lowercased()
                let notes   = entry.notes.lowercased()
                let loc     = EntryFormatting.locationLabel(for: entry, savedLocations: savedLocationStore.locations).lowercased()
                let tags    = entry.tags.joined(separator: " ").lowercased()
                return species.contains(q) || camera.contains(q) || notes.contains(q) || loc.contains(q) || tags.contains(q)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                AppHeader(
                    title: "Entries",
                    subtitle: "\(finalizedEntries.count) finalized observations"
                )

                TextField("Search species, location, notes, tags…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                // Tag filter chips — only shown when entries have tags
                if !allTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allTags, id: \.self) { tag in
                                let isActive = selectedTag == tag
                                Button {
                                    selectedTag = isActive ? nil : tag
                                } label: {
                                    // P8: show × on active chip to allow clearing
                                    HStack(spacing: 4) {
                                        Text("#\(tag)")
                                            .font(.footnote)
                                        if isActive {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .bold))
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(isActive ? Color.accentColor : Color.secondary.opacity(0.15))
                                    .foregroundStyle(isActive ? Color.white : Color.primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                List {
                    ForEach(filteredEntries) { entry in
                        NavigationLink {
                            EntryDetailView(entryID: entry.id)
                        } label: {
                            EntryRow(entry: entry, locationText: EntryFormatting.locationLabel(for: entry, savedLocations: savedLocationStore.locations))
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
