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

    private var totalCameraEntries: Int {
        entries.filter { !($0.camera ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppHeader(title: "Camera Ranking", subtitle: "\(ranking.count) cameras in current filter")

                StatsSearchField(text: $searchText, placeholder: "Search cameras")
                    .padding(.horizontal)

                StatsCard(title: "All Cameras") {
                    if ranking.isEmpty {
                        Text("No cameras found")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(ranking.enumerated()), id: \.element.id) { index, item in
                                let pct = totalCameraEntries == 0 ? 0 : Int((Double(item.count) / Double(totalCameraEntries)) * 100)

                                NavigationLink {
                                    CameraDetailView(cameraName: item.name, allEntries: entries)
                                } label: {
                                    HStack(spacing: 10) {
                                        Text("#\(index + 1)")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(AppColors.textSecondary)
                                            .frame(width: 30, alignment: .leading)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .foregroundStyle(AppColors.primary)
                                            Text("\(pct)% of camera-tagged entries")
                                                .font(.caption)
                                                .foregroundStyle(AppColors.textSecondary)
                                        }

                                        Spacer()

                                        Text("\(item.count)")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                                .buttonStyle(.plain)

                                if item.id != ranking.last?.id {
                                    Divider().opacity(0.25)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .appScreenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
