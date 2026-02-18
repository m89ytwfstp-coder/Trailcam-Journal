//
//  Untitled.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 08/01/2026.
//

import SwiftUI

struct SavedLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var savedLocationStore: SavedLocationStore

    let onPick: (SavedLocation) -> Void

    @State private var searchText = ""

    private var filtered: [SavedLocation] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return savedLocationStore.locations
        }
        return savedLocationStore.locations.filter { loc in
            loc.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    Text("No matching locations.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { loc in
                        Button {
                            onPick(loc)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc.name)
                                    .font(.headline)

                                Text("\(loc.latitude), \(loc.longitude)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("Choose location")
            .searchable(text: $searchText, prompt: "Search saved locations")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
