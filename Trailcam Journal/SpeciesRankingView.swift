//
//  SpeciesRankingView.swift
//  Trailcam Journal
//

import SwiftUI

struct SpeciesRankingView: View {
    let entries: [TrailEntry]
    @State private var searchText: String = ""

    private var ranking: [RankedCount] {
        let all = StatsHelpers.allSpeciesRanking(entries: entries)
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return all }
        let q = searchText.lowercased()
        return all.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        List {
            Section {
                ForEach(ranking) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text("\(item.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Species")
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Species ranking")
        .navigationBarTitleDisplayMode(.inline)
    }
}
