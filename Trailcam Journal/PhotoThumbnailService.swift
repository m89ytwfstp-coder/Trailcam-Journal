//
//  PhotoThumbnailService.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 16/01/2026.
//

import Foundation
import UIKit
import Photos

/// Loads images from the user's Photos library using PHAsset local identifiers,
/// and caches thumbnails to disk (Caches folder) for fast scrolling lists.
final class PhotoThumbnailService {
    static let shared = PhotoThumbnailService()

    private let manager = PHCachingImageManager()

    private init() {}

    // MARK: - Public API

    /// Loads a thumbnail for a Photos asset id.
    /// - Parameters:
    ///   - assetId: PHAsset.localIdentifier stored in TrailEntry.photoAssetId
    ///   - maxPixel: thumbnail size target (e.g. 250, 400, 1200)
    /// - Returns: UIImage? on the calling (background) context; switch to MainActor in callers.
    func loadThumbnail(assetId: String, maxPixel: Int) async -> UIImage? {
        // 1) Disk cache hit — synchronous read off main thread is fine here.
        if let cached = ImageStorage.loadCachedThumbnail(assetId: assetId, maxPixel: maxPixel) {
            return cached
        }

        // 2) Fetch asset
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = result.firstObject else { return nil }

        // 3) Request image from Photos via continuation (avoids blocking the calling task).
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: maxPixel, height: maxPixel)

        return await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image {
                    ImageStorage.saveCachedThumbnail(image, assetId: assetId, maxPixel: maxPixel)
                }
                continuation.resume(returning: image)
            }
        }
    }

    /// Loads a larger "detail" image suitable for fullscreen-ish display.
    func loadDetailImage(assetId: String, maxPixel: Int) async -> UIImage? {
        await loadThumbnail(assetId: assetId, maxPixel: maxPixel)
    }
}
