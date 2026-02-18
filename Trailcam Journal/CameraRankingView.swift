//
//  CameraRankingView.swift
//  Trailcam Journal
//

import SwiftUI

struct CameraRankingView: View {
    let entries: [TrailEntry]
    @State private var searchText: String = ""

    private var ranking: [RankedCount] {
        let all = StatsHelpers.allCameraRanking(entries: entries)
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return all }
        let q = searchText.lowercased()
        return all.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        List {
            Section {
                ForEach(ranking) { item in
                    NavigationLink {
                        CameraDetailView(cameraName: item.name, allEntries: entries)
                    } label: {
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text("\(item.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Cameras")
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Cameras")
        .navigationBarTitleDisplayMode(.inline)
    }
}
