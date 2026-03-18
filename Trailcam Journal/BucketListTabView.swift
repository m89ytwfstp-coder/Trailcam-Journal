//
//  BucketListTabView.swift
//  Trailcam Journal
//

import SwiftUI

struct BucketListTabView: View {
    @EnvironmentObject var store: EntryStore

    private var seenCount: Int {
        let seenIDs = BucketListLogic.firstSightingBySpeciesID(from: store.entries)
        return SpeciesCatalog.all.filter { seenIDs[$0.id] != nil }.count
    }

    private var totalCount: Int { SpeciesCatalog.all.count }

    private var progressFraction: Double {
        totalCount > 0 ? Double(seenCount) / Double(totalCount) : 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AppHeader(
                        title: "Bucket List",
                        subtitle: "Unlock species — first sighting date"
                    )

                    // Progress indicator
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(seenCount) of \(totalCount) species observed")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppColors.primary.opacity(0.12))
                                    .frame(height: 6)
                                Capsule()
                                    .fill(AppColors.primary.opacity(0.70))
                                    .frame(width: geo.size.width * progressFraction, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.horizontal)

                    BucketListView()
                        .padding(.top, 4)

                    Spacer(minLength: 20)
                }
                .padding(.top, 2)
            }
            .appScreenBackground()
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
