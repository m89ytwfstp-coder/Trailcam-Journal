//
//  BucketListView.swift
//  Trailcam Journal
//

import SwiftUI

struct BucketListView: View {
    @EnvironmentObject var store: EntryStore

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 12)
    ]

    private var firstSightingByID: [String: Date] {
        BucketListLogic.firstSightingBySpeciesID(from: store.entries)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(SpeciesCatalog.all) { species in
                BucketSpeciesTile(
                    species: species,
                    firstSightingDate: firstSightingByID[species.id]
                )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Tile

private struct BucketSpeciesTile: View {
    let species: Species
    let firstSightingDate: Date?

    @State private var photo: PlatformImage? = nil
    @State private var fetchComplete = false

    private var isSeen: Bool { firstSightingDate != nil }

    private var initial: String {
        String(species.nameNO.prefix(1)).uppercased()
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            // ── Square image area ─────────────────────────────────────
            GeometryReader { geo in
                ZStack {
                    if let photo {
                        photoImage(photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                            .opacity(isSeen ? 1.0 : 0.35)
                    } else {
                        initialLetterPlaceholder(size: geo.size.width)
                            .opacity(isSeen ? 1.0 : 0.5)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)   // ← enforces square

            // ── Name + date overlay ───────────────────────────────────
            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(species.nameNO)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)

                    if let date = firstSightingDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // ── Checkmark badge (bottom-right, teal circle) ───────────
            if isSeen {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(Circle().fill(AppColors.primary))
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSeen
                        ? Color.accentColor.opacity(0.6)
                        : Color.black.opacity(0.15),
                    lineWidth: isSeen ? 2 : 1
                )
        )
        .task {
            guard photo == nil else { return }
            if let localURL = await SpeciesPhotoService.localPhotoURL(for: species) {
                let loaded = loadImage(from: localURL)
                await MainActor.run { photo = loaded }
            } else {
                await MainActor.run { fetchComplete = true }
            }
        }
    }

    // MARK: - Helpers

    /// Cross-platform image loading from a local file URL.
    private func loadImage(from url: URL) -> PlatformImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }

    /// Cross-platform SwiftUI Image from PlatformImage.
    @ViewBuilder
    private func photoImage(_ img: PlatformImage) -> Image {
        #if os(macOS)
        Image(nsImage: img)
        #else
        Image(uiImage: img)
        #endif
    }

    /// Initial-letter placeholder — warm background, large letter.
    private func initialLetterPlaceholder(size: CGFloat) -> some View {
        ZStack {
            Color(red: 0.91, green: 0.90, blue: 0.87)
            Text(initial)
                .font(.system(size: size * 0.42, weight: .light, design: .rounded))
                .foregroundStyle(Color(white: 0.55))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Platform type alias

#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif
