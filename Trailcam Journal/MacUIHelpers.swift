
//
//  MacUIHelpers.swift
//  Trailcam Journal
//
//  Shared macOS helpers: thumbnail view + image storage backend.
//

#if os(macOS)
import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

// ── Thumbnail view ───────────────────────────────────────────────────────────

/// Rounded photo thumbnail backed by MacImageStore.
/// Displays the image letterboxed (scaledToFit) on a black background.
/// When `overlayTitle` is provided a gradient label bar appears at the bottom.
struct MacThumbnail: View {
    let entry: TrailEntry?
    var cornerRadius: CGFloat = 10
    var overlayTitle: String? = nil

    var body: some View {
        Group {
            if let entry, let image = MacImageStore.loadThumbnail(for: entry) {
                ZStack(alignment: .bottom) {
                    Color.black
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                    if let title = overlayTitle, !title.isEmpty {
                        // P8: deeper scrim covering bottom 40% for legibility on daytime shots
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 40)
                        Text(title)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 4)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay {
                        Image(systemName: entry?.entryType.symbol ?? "photo")
                            .font(.title3)
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// ── Image storage backend ────────────────────────────────────────────────────

// ── Image pair returned from saveImagePair ────────────────────────────────────

struct MacImagePair {
    let thumbnailFilename: String   // 400 px — used in list views
    let displayFilename:   String   // 1200 px — used in detail view
}

enum MacImageStore {

    static func fileURL(for filename: String) -> URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(filename)
    }

    // MARK: - Load helpers

    /// Load the display-size image for the detail view (uses photoFilename).
    static func loadImage(for entry: TrailEntry) -> NSImage? {
        guard let name = entry.photoFilename,
              let url  = fileURL(for: name) else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Load the 400 px thumbnail for list views, with NSCache.
    /// Falls back to photoFilename for legacy entries that have no thumbnail yet.
    static func loadThumbnail(for entry: TrailEntry) -> NSImage? {
        let name: String
        if let t = entry.photoThumbnailFilename, !t.isEmpty {
            name = t
        } else if let f = entry.photoFilename, !f.isEmpty {
            name = f
        } else {
            return nil
        }

        if let cached = MacThumbnailCache.shared.image(for: name) { return cached }

        guard let url   = fileURL(for: name),
              let image = NSImage(contentsOf: url) else { return nil }
        MacThumbnailCache.shared.store(image, for: name)
        return image
    }

    // MARK: - Save helpers

    /// Save both a 400 px thumbnail and a 1200 px display image from raw data.
    static func saveImagePair(data: Data) -> MacImagePair? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let thumbFilename   = saveResized(source: source, maxPixel: 400,  quality: 0.70),
              let displayFilename = saveResized(source: source, maxPixel: 1200, quality: 0.75)
        else { return nil }
        return MacImagePair(thumbnailFilename: thumbFilename, displayFilename: displayFilename)
    }

    private static func saveResized(source: CGImageSource, maxPixel: Int, quality: CGFloat) -> String? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform:   true,
            kCGImageSourceThumbnailMaxPixelSize:           maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary
        ) else { return nil }

        let filename = UUID().uuidString + ".jpg"
        guard let outputURL  = fileURL(for: filename),
              let destination = CGImageDestinationCreateWithURL(
                  outputURL as CFURL,
                  UTType.jpeg.identifier as CFString,
                  1, nil
              )
        else { return nil }

        CGImageDestinationAddImage(
            destination, cgImage,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return filename
    }

    /// Deletes a stored file by filename (best-effort).
    static func deleteFile(filename: String) {
        guard let url = fileURL(for: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Legacy single-file save (kept for any remaining call sites)

    @available(*, deprecated, renamed: "saveImagePair")
    static func saveDownsampledJPEG(
        data: Data,
        maxPixel: Int = 2400,
        quality: CGFloat = 0.82
    ) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return saveResized(source: source, maxPixel: maxPixel, quality: quality)
    }
}

// ── Draft status helpers ─────────────────────────────────────────────────────

enum MacDraftStatus: Equatable {
    case missingSpecies
    case missingLocation
    case missingNotes
    case missingNestbox
    case ready

    init(entry: TrailEntry) {
        switch entry.entryType {
        case .sighting:
            if entry.species?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                self = .missingSpecies
            } else if !entry.locationUnknown && entry.latitude == nil {
                self = .missingLocation
            } else {
                self = .ready
            }
        case .track:
            if !entry.locationUnknown && entry.latitude == nil {
                self = .missingLocation
            } else {
                self = .ready
            }
        case .fieldNote:
            if entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self = .missingNotes
            } else {
                self = .ready
            }
        case .nestbox:
            if entry.nestboxID == nil {
                self = .missingNestbox
            } else {
                self = .ready
            }
        }
    }

    var label: String {
        switch self {
        case .missingSpecies:  "Missing species"
        case .missingLocation: "Missing location"
        case .missingNotes:    "Add notes to finalise"
        case .missingNestbox:  "Select a nestbox"
        case .ready:           "Ready to finalise"
        }
    }

    var shortLabel: String {
        switch self {
        case .missingSpecies:  "No species"
        case .missingLocation: "No location"
        case .missingNotes:    "No notes"
        case .missingNestbox:  "No nestbox"
        case .ready:           "Ready"
        }
    }

    var color: Color {
        switch self {
        case .missingSpecies, .missingLocation, .missingNotes, .missingNestbox: .orange
        case .ready:                                                             AppColors.secondary
        }
    }
}
#endif
