//
//  Untitled.swift
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
    ///   - completion: returns UIImage? on main thread
    func loadThumbnail(assetId: String, maxPixel: Int, completion: @escaping (UIImage?) -> Void) {
        // 1) Disk cache hit?
        if let cached = ImageStorage.loadCachedThumbnail(assetId: assetId, maxPixel: maxPixel) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        // 2) Fetch asset
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = result.firstObject else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        // 3) Request image from Photos (fast thumbnail)
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        // targetSize is in *pixels*; use maxPixel for both (square target)
        let targetSize = CGSize(width: maxPixel, height: maxPixel)

        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image {
                // Save to disk cache for next time
                ImageStorage.saveCachedThumbnail(image, assetId: assetId, maxPixel: maxPixel)
            }
            DispatchQueue.main.async { completion(image) }
        }
    }

    /// Loads a larger “detail” image suitable for fullscreen-ish display.
    /// Still uses caching (separate size key).
    func loadDetailImage(assetId: String, maxPixel: Int, completion: @escaping (UIImage?) -> Void) {
        // Reuse the same thumbnail pipeline, just bigger target.
        loadThumbnail(assetId: assetId, maxPixel: maxPixel, completion: completion)
    }
}
