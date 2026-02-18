//
//  BucketListView.swift
//  Trailcam Journal
//

import SwiftUI

struct BucketListView: View {
    @EnvironmentObject var store: EntryStore

    // Adaptive grid (works on iPhone + iPad)
    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 12)
    ]

    // Compute first sightings once per render
    private var firstSightingByID: [String: Date] {
        BucketListLogic.firstSightingBySpeciesID(from: store.entries)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(SpeciesCatalog.all) { species in
                let firstDate = firstSightingByID[species.id]

                BucketSpeciesTile(
                    species: species,
                    firstSightingDate: firstDate
                )
            }
        }
        .padding(.horizontal)
    }
}

private struct BucketSpeciesTile: View {
    let species: Species
    let firstSightingDate: Date?

    private var isSeen: Bool {
        firstSightingDate != nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {

            // Background image fills entire card
            Image(species.thumbnailName)
                .resizable()
                .scaledToFill()
                .scaleEffect(1.28)                 // zoom in to hide the baked-in inner frame
                .frame(maxWidth: .infinity, minHeight: 110)
                .clipped()
                .opacity(isSeen ? 1.0 : 0.35)


            // Bottom text overlay
            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(species.nameNO)
                        .font(.caption.bold())
                        .foregroundStyle(.black)

                    if let date = firstSightingDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.black.opacity(0.7))
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Checkmark badge
            if isSeen {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.black)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.85))
                    )
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.35), lineWidth: 2)
        )
    }


}
