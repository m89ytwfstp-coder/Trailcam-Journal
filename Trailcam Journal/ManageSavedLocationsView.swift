//
//  ManageSavedLocationsView.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 08/01/2026.
//

import SwiftUI

struct ManageSavedLocationsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var savedLocationStore: SavedLocationStore

    var body: some View {
        NavigationStack {
            List {
                if savedLocationStore.locations.isEmpty {
                    Text("No saved locations yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(savedLocationStore.locations) { loc in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loc.name)
                                .font(.headline)

                            Text("\(loc.latitude), \(loc.longitude)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { offsets in
                        savedLocationStore.remove(at: offsets)
                    }
                }
            }
            .navigationTitle("Saved locations")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}
