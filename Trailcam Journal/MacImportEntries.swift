import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

#if os(macOS)
struct MacImportPane: View {
    @EnvironmentObject private var store: EntryStore

    @State private var isImporting = false
    @State private var lastImportCount: Int?
    @State private var lastError: String?

    private var drafts: [TrailEntry] {
        store.entries
            .filter { $0.isDraft }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppHeader(
                title: "Import",
                subtitle: "\(drafts.count) draft entries waiting for review"
            )

            HStack(spacing: 10) {
                Button {
                    importFromOpenPanel()
                } label: {
                    Label("Import Photos…", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting)

                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }
            .padding(.horizontal)

            if let lastImportCount {
                Text("Imported \(lastImportCount) image(s).")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal)
            }

            if let lastError {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            if drafts.isEmpty {
                ContentUnavailableView(
                    "No drafts yet",
                    systemImage: "photo.stack",
                    description: Text("Use Import Photos to create draft entries from local image files.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(drafts) { entry in
                    HStack(spacing: 10) {
                        MacEntryThumbnail(entry: entry)
                            .frame(width: 72, height: 52)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.originalFilename ?? "Untitled image")
                                .font(.headline)
                                .lineLimit(1)

                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.footnote)
                                .foregroundStyle(AppColors.textSecondary)

                            Text(draftStatus(for: entry))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appScreenBackground()
    }

    private func draftStatus(for entry: TrailEntry) -> String {
        if entry.species?.isEmpty != false { return "Missing species" }
        if entry.locationUnknown || (entry.latitude != nil && entry.longitude != nil) { return "Ready to finalize" }
        return "Missing location"
    }

    private func importFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.jpeg, .png, .tiff, .heic, .heif, .image]

        let response = panel.runModal()
        guard response == .OK else { return }

        let urls = panel.urls
        guard !urls.isEmpty else { return }

        isImporting = true
        lastImportCount = nil
        lastError = nil

        var imported = 0

        for url in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            let meta = extractMetadata(from: data)
            guard let filename = MacImageStore.saveDownsampledJPEG(data: data) else { continue }

            let entry = TrailEntry(
                id: UUID(),
                date: meta.date ?? Date(),
                species: nil,
                camera: nil,
                notes: "",
                tags: [],
                photoFilename: filename,
                latitude: meta.latitude,
                longitude: meta.longitude,
                locationUnknown: false,
                isDraft: true,
                originalFilename: url.lastPathComponent,
                photoAssetId: nil
            )

            store.entries.insert(entry, at: 0)
            imported += 1
        }

        isImporting = false
        lastImportCount = imported

        if imported == 0 {
            lastError = "No images were imported. Check file permissions or image format."
        }
    }

    private func extractMetadata(from data: Data) -> (date: Date?, latitude: Double?, longitude: Double?) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return (nil, nil, nil)
        }

        var date: Date?
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let raw = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            date = parseExifDate(raw)
        }
        if date == nil,
           let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let raw = tiff[kCGImagePropertyTIFFDateTime] as? String {
            date = parseExifDate(raw)
        }

        var lat: Double?
        var lon: Double?
        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            lat = gps[kCGImagePropertyGPSLatitude] as? Double
            lon = gps[kCGImagePropertyGPSLongitude] as? Double

            if let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
               latRef.uppercased() == "S",
               let value = lat {
                lat = -abs(value)
            }
            if let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String,
               lonRef.uppercased() == "W",
               let value = lon {
                lon = -abs(value)
            }
        }

        return (date, lat, lon)
    }

    private func parseExifDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: raw)
    }
}

struct MacEntriesPane: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore

    @State private var searchText = ""
    @State private var pendingDelete: TrailEntry?
    @State private var showDeleteAlert = false

    private var finalizedEntries: [TrailEntry] {
        store.entries
            .filter { !$0.isDraft }
            .sorted { $0.date > $1.date }
    }

    private var filteredEntries: [TrailEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return finalizedEntries }

        return finalizedEntries.filter { entry in
            let species = (entry.species ?? "").lowercased()
            let camera = (entry.camera ?? "").lowercased()
            let notes = entry.notes.lowercased()
            let location = locationLabel(for: entry).lowercased()
            return species.contains(q) || camera.contains(q) || notes.contains(q) || location.contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppHeader(
                title: "Entries",
                subtitle: "\(finalizedEntries.count) finalized observations"
            )

            TextField("Search species, location, notes…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    "No finalized entries",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Finalize imported drafts to see them here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredEntries) { entry in
                    HStack(spacing: 10) {
                        MacEntryThumbnail(entry: entry)
                            .frame(width: 72, height: 52)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.species ?? "Unknown species")
                                .font(.headline)
                                .lineLimit(1)

                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.footnote)
                                .foregroundStyle(AppColors.textSecondary)

                            Text(locationLabel(for: entry))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button(role: .destructive) {
                            pendingDelete = entry
                            showDeleteAlert = true
                        } label: {
                            Label("Delete Entry", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appScreenBackground()
        .alert("Delete entry?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let id = pendingDelete?.id {
                    store.deleteEntry(id: id)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("This will permanently delete this entry.")
        }
    }

    private func locationLabel(for entry: TrailEntry) -> String {
        if entry.locationUnknown { return "Unknown location" }
        guard let lat = entry.latitude, let lon = entry.longitude else { return "No location" }

        let rLat = (lat * 10000).rounded() / 10000
        let rLon = (lon * 10000).rounded() / 10000
        if let saved = savedLocationStore.locations.first(where: { loc in
            let lrLat = (loc.latitude * 10000).rounded() / 10000
            let lrLon = (loc.longitude * 10000).rounded() / 10000
            return lrLat == rLat && lrLon == rLon
        }) {
            return saved.name
        }
        return String(format: "%.4f, %.4f", lat, lon)
    }
}

private struct MacEntryThumbnail: View {
    let entry: TrailEntry

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.15))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func loadImage() -> NSImage? {
        guard let name = entry.photoFilename,
              let url = MacImageStore.fileURL(for: name) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

private enum MacImageStore {
    static func fileURL(for filename: String) -> URL? {
        documentsDirectory()?.appendingPathComponent(filename)
    }

    static func saveDownsampledJPEG(data: Data, maxPixel: Int = 2400, quality: CGFloat = 0.82) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let filename = UUID().uuidString + ".jpg"
        guard let outputURL = fileURL(for: filename),
              let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }

        let destOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, destOptions as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return filename
    }

    private static func documentsDirectory() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}
#endif
