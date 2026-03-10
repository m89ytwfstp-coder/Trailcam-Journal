//
//  MacThumbnailCache.swift
//  Trailcam Journal
//
//  In-memory NSCache for 400 px Mac list-view thumbnails.
//  Capped at 200 images / 50 MB to stay responsive on large libraries.
//

#if os(macOS)
import AppKit

final class MacThumbnailCache {
    static let shared = MacThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit     = 200
        cache.totalCostLimit = 50 * 1024 * 1024   // 50 MB
    }

    func image(for filename: String) -> NSImage? {
        cache.object(forKey: filename as NSString)
    }

    func store(_ image: NSImage, for filename: String) {
        // Cost ≈ raw pixel bytes (RGBA)
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: filename as NSString, cost: cost)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
#endif
