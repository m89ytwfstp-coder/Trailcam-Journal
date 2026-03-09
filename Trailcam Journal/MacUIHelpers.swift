
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
struct MacThumbnail: View {
    let entry: TrailEntry?
    var cornerRadius: CGFloat = 10

    var body: some View {
        Group {
            if let entry, let image = MacImageStore.loadImage(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// ── Image storage backend ────────────────────────────────────────────────────

enum MacImageStore {

    static func fileURL(for filename: String) -> URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(filename)
    }

    static func loadImage(for entry: TrailEntry) -> NSImage? {
        guard let name = entry.photoFilename,
              let url  = fileURL(for: name) else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Downsample and save a JPEG from raw image data; returns the filename.
    static func saveDownsampledJPEG(
        data: Data,
        maxPixel: Int = 2400,
        quality: CGFloat = 0.82
    ) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform:  true,
            kCGImageSourceThumbnailMaxPixelSize:          maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbOptions as CFDictionary
        ) else { return nil }

        let filename = UUID().uuidString + ".jpg"
        guard let outputURL   = fileURL(for: filename),
              let destination  = CGImageDestinationCreateWithURL(
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
}

// ── Draft status helpers ─────────────────────────────────────────────────────

enum MacDraftStatus {
    case missingSpecies
    case missingLocation
    case ready

    init(entry: TrailEntry) {
        if entry.species?.isEmpty != false {
            self = .missingSpecies
        } else if !entry.locationUnknown && entry.latitude == nil {
            self = .missingLocation
        } else {
            self = .ready
        }
    }

    var label: String {
        switch self {
        case .missingSpecies:  "Missing species"
        case .missingLocation: "Missing location"
        case .ready:           "Ready to finalise"
        }
    }

    var color: Color {
        switch self {
        case .missingSpecies, .missingLocation: .orange
        case .ready:                            AppColors.secondary
        }
    }
}
#endif
