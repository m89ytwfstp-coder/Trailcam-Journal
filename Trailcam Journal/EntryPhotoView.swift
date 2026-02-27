//
//  EntryPhotoView.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 16/01/2026.
//
//  FIX (Jan 2026):
//  - Avoid "sticky" thumbnails when SwiftUI reuses views.
//  - Reload image when the underlying entry reference changes using .task(id:).
//

import SwiftUI
import UIKit

/// Reusable SwiftUI image view for a TrailEntry.
/// Priority:
/// 1) If entry.photoAssetId exists -> load from Photos + cached thumbnails
/// 2) Else if entry.photoFilename exists (legacy) -> load from Documents
/// 3) Else -> placeholder
struct EntryPhotoView: View {
    let entry: TrailEntry
    let height: CGFloat
    let cornerRadius: CGFloat
    let maxPixel: Int

    @State private var uiImage: UIImage? = nil

    private var cacheKey: String {
        if let a = entry.photoAssetId, !a.isEmpty { return "asset:\(a)-\(maxPixel)" }
        if let f = entry.photoFilename, !f.isEmpty { return "file:\(f)" }
        return "id:\(entry.id.uuidString)"
    }

    var body: some View {
        Group {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.15))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .clipped()
        .task(id: cacheKey) {
            uiImage = nil
            await load()
        }
    }

    @MainActor
    private func load() async {
        let expectedKey = cacheKey

        // 1) Preferred: Photos asset reference
        if let assetId = entry.photoAssetId, !assetId.isEmpty {
            PhotoThumbnailService.shared.loadThumbnail(assetId: assetId, maxPixel: maxPixel) { image in
                guard expectedKey == cacheKey else { return }
                self.uiImage = image
            }
            return
        }

        // 2) Legacy fallback: Documents filename
        if let filename = entry.photoFilename,
           let legacy = ImageStorage.loadUIImageFromDocuments(filename: filename) {
            guard expectedKey == cacheKey else { return }
            self.uiImage = legacy
            return
        }

        // 3) Nothing
        guard expectedKey == cacheKey else { return }
        self.uiImage = nil
    }
}
