import Foundation
import UIKit
import CryptoKit
import ImageIO

enum ImageStorage {

    // MARK: - Legacy Documents storage (old versions)

    static func saveJPEGToDocuments(data: Data) -> String? {
        let filename = UUID().uuidString + ".jpg"
        guard let url = documentsDirectory()?.appendingPathComponent(filename) else { return nil }

        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    /// Saves a downsampled JPEG to Documents to reduce app storage growth.
    static func saveDownsampledJPEGToDocuments(
        data: Data,
        maxPixel: Int = 2400,
        compressionQuality: CGFloat = 0.82
    ) -> String? {
        let filename = UUID().uuidString + ".jpg"
        guard let url = documentsDirectory()?.appendingPathComponent(filename) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)
        guard let jpegData = image.jpegData(compressionQuality: compressionQuality) else { return nil }

        do {
            try jpegData.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    static func loadUIImageFromDocuments(filename: String) -> UIImage? {
        guard let url = documentsDirectory()?.appendingPathComponent(filename) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Deletes a legacy full-size JPEG from Documents (best-effort).
    static func deleteJPEGFromDocuments(filename: String) {
        guard let url = documentsDirectory()?.appendingPathComponent(filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Thumbnail cache (Option B)

    static func loadCachedThumbnail(assetId: String, maxPixel: Int) -> UIImage? {
        guard let url = cachedThumbnailURL(assetId: assetId, maxPixel: maxPixel) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func saveCachedThumbnail(_ image: UIImage, assetId: String, maxPixel: Int) {
        guard let url = cachedThumbnailURL(assetId: assetId, maxPixel: maxPixel) else { return }
        guard let data = image.jpegData(compressionQuality: 0.80) else { return }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            // non-fatal
        }
    }

    private static func cachedThumbnailURL(assetId: String, maxPixel: Int) -> URL? {
        guard let dir = cachesThumbsDirectory() else { return nil }
        let key = sha256Hex(assetId)
        let filename = "\(key)_\(maxPixel).jpg"
        return dir.appendingPathComponent(filename)
    }

    private static func cachesThumbsDirectory() -> URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("TrailcamThumbs", isDirectory: true)

        if !FileManager.default.fileExists(atPath: dir.path) {
            do { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
            catch { return nil }
        }

        return dir
    }

    /// Clears the thumbnail cache folder (best-effort). Safe to call any time.
    static func clearThumbnailCache() {
        guard let dir = cachesThumbsDirectory() else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    private static func documentsDirectory() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private static func sha256Hex(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
