import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

#if os(macOS)
private struct EntryEditorSelection: Identifiable {
    let id: UUID
}

struct MacImportPane: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore

    @State private var isImporting = false
    @State private var lastImportCount: Int?
    @State private var lastError: String?
    @State private var lastDuplicateSkipCount = 0
    @State private var selectedDraftIDs: Set<UUID> = []
    @State private var showSpeciesSheet = false
    @State private var showLocationSheet = false
    @State private var batchSpecies = ""
    @State private var batchLocationUnknown = false
    @State private var batchLatitudeText = ""
    @State private var batchLongitudeText = ""
    @State private var selectedSavedLocationID: UUID?
    @State private var showDeleteConfirmation = false
    @State private var showFinalizeSummary = false
    @State private var finalizeSummary = ""
    @State private var editorSelection: EntryEditorSelection?

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
                .keyboardShortcut("i", modifiers: .command)

                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }
            .padding(.horizontal)

            if !drafts.isEmpty {
                draftActionsBar
            }

            if let lastImportCount {
                Text(importResultText(imported: lastImportCount, skippedDuplicates: lastDuplicateSkipCount))
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
                List(drafts, selection: $selectedDraftIDs) { entry in
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

                        Spacer()

                        Button("Edit") {
                            editorSelection = EntryEditorSelection(id: entry.id)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button("Edit") {
                            editorSelection = EntryEditorSelection(id: entry.id)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appScreenBackground()
        .sheet(isPresented: $showSpeciesSheet) {
            speciesSheet
        }
        .sheet(isPresented: $showLocationSheet) {
            locationSheet
        }
        .sheet(item: $editorSelection) { selection in
            MacEntryEditorPane(entryID: selection.id)
        }
        .alert("Delete selected drafts?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedDrafts()
            }
        } message: {
            Text("This will permanently delete the selected draft entries.")
        }
        .alert("Finalize result", isPresented: $showFinalizeSummary) {
            Button("OK") {}
        } message: {
            Text(finalizeSummary)
        }
    }

    private func draftStatus(for entry: TrailEntry) -> String {
        if entry.species?.isEmpty != false { return "Missing species" }
        if entry.locationUnknown || (entry.latitude != nil && entry.longitude != nil) { return "Ready to finalize" }
        return "Missing location"
    }

    private var selectedDraftIndexes: [Int] {
        store.entries.indices.filter { selectedDraftIDs.contains(store.entries[$0].id) && store.entries[$0].isDraft }
    }

    private var selectedCount: Int {
        selectedDraftIndexes.count
    }

    private var draftActionsBar: some View {
        HStack(spacing: 10) {
            Button("Set Species…") {
                showSpeciesSheet = true
            }
            .disabled(selectedCount == 0)
            .keyboardShortcut("s", modifiers: .command)

            Button("Set Location…") {
                prepareLocationSheet()
                showLocationSheet = true
            }
            .disabled(selectedCount == 0)
            .keyboardShortcut("l", modifiers: .command)

            Button("Mark Location Unknown") {
                markLocationUnknownForSelected()
            }
            .disabled(selectedCount == 0)

            Button("Finalize Selected") {
                finalizeSelectedDrafts()
            }
            .disabled(selectedCount == 0)
            .keyboardShortcut(.return, modifiers: .command)

            Button("Delete Selected", role: .destructive) {
                showDeleteConfirmation = true
            }
            .disabled(selectedCount == 0)
            .keyboardShortcut(.delete, modifiers: .command)

            Spacer()

            Text(selectedCount == 0 ? "Select drafts to edit" : "\(selectedCount) selected")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal)
    }

    private var locationSheet: some View {
        NavigationStack {
            Form {
                Toggle("Mark location as unknown", isOn: $batchLocationUnknown)

                Picker("Saved location", selection: $selectedSavedLocationID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(savedLocationStore.locations) { location in
                        Text(location.name).tag(Optional(location.id))
                    }
                }
                .onChange(of: selectedSavedLocationID) { _, id in
                    guard let id,
                          let location = savedLocationStore.locations.first(where: { $0.id == id }) else { return }
                    batchLatitudeText = String(location.latitude)
                    batchLongitudeText = String(location.longitude)
                    batchLocationUnknown = false
                }

                TextField("Latitude", text: $batchLatitudeText)
                    .disabled(batchLocationUnknown)
                TextField("Longitude", text: $batchLongitudeText)
                    .disabled(batchLocationUnknown)
            }
            .navigationTitle("Set Location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showLocationSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyLocationToSelected()
                        showLocationSheet = false
                    }
                    .disabled(!canApplyLocation)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 240)
    }

    private var canApplyLocation: Bool {
        if batchLocationUnknown { return selectedCount > 0 }
        return selectedCount > 0 && parseCoordinate(batchLatitudeText) != nil && parseCoordinate(batchLongitudeText) != nil
    }

    private var speciesSheet: some View {
        NavigationStack {
            Form {
                Picker("Species", selection: $batchSpecies) {
                    Text("— Select —").tag("")
                    ForEach(SpeciesCatalog.all) { species in
                        Text(species.nameNO).tag(species.nameNO)
                    }
                }
            }
            .navigationTitle("Set Species")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showSpeciesSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applySpeciesToSelected()
                        showSpeciesSheet = false
                    }
                    .disabled(batchSpecies.isEmpty || selectedCount == 0)
                }
            }
            .onAppear {
                batchSpecies = ""
            }
        }
        .frame(minWidth: 360, minHeight: 180)
    }

    private func applySpeciesToSelected() {
        guard !batchSpecies.isEmpty else { return }
        for i in selectedDraftIndexes {
            store.entries[i].species = batchSpecies
        }
    }

    private func markLocationUnknownForSelected() {
        for i in selectedDraftIndexes {
            store.entries[i].locationUnknown = true
            store.entries[i].latitude = nil
            store.entries[i].longitude = nil
        }
    }

    private func prepareLocationSheet() {
        batchLocationUnknown = false
        batchLatitudeText = ""
        batchLongitudeText = ""
        selectedSavedLocationID = nil
    }

    private func parseCoordinate(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private func applyLocationToSelected() {
        if batchLocationUnknown {
            markLocationUnknownForSelected()
            return
        }

        guard let lat = parseCoordinate(batchLatitudeText),
              let lon = parseCoordinate(batchLongitudeText) else { return }

        for i in selectedDraftIndexes {
            store.entries[i].locationUnknown = false
            store.entries[i].latitude = lat
            store.entries[i].longitude = lon
        }
    }

    private func finalizeSelectedDrafts() {
        var finalized = 0
        var skipped = 0

        for i in selectedDraftIndexes {
            if store.entries[i].canFinalize {
                store.entries[i].isDraft = false
                finalized += 1
            } else {
                skipped += 1
            }
        }

        selectedDraftIDs.removeAll()
        finalizeSummary = skipped > 0
            ? "Finalized \(finalized). Skipped \(skipped) because required information is missing."
            : "Finalized \(finalized) draft(s)."
        showFinalizeSummary = true
    }

    private func deleteSelectedDrafts() {
        let ids = Set(selectedDraftIndexes.map { store.entries[$0].id })
        guard !ids.isEmpty else { return }
        store.deleteEntries(ids: ids)
        selectedDraftIDs.removeAll()
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
        lastDuplicateSkipCount = 0
        lastError = nil

        var imported = 0
        var skippedDuplicates = 0
        var existingHashes = existingLocalImageHashes()

        for url in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            let hash = sha256Hex(data)
            if existingHashes.contains(hash) {
                skippedDuplicates += 1
                continue
            }

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
            existingHashes.insert(hash)
            imported += 1
        }

        isImporting = false
        lastImportCount = imported
        lastDuplicateSkipCount = skippedDuplicates

        if imported == 0 {
            if skippedDuplicates > 0 {
                lastError = "No new images imported. \(skippedDuplicates) duplicate image(s) skipped."
            } else {
                lastError = "No images were imported. Check file permissions or image format."
            }
        }
    }

    private func importResultText(imported: Int, skippedDuplicates: Int) -> String {
        if skippedDuplicates > 0 {
            return "Imported \(imported) image(s), skipped \(skippedDuplicates) duplicate(s)."
        }
        return "Imported \(imported) image(s)."
    }

    private func existingLocalImageHashes() -> Set<String> {
        var hashes: Set<String> = []
        for entry in store.entries {
            guard let filename = entry.photoFilename,
                  let url = MacImageStore.fileURL(for: filename),
                  let data = try? Data(contentsOf: url) else { continue }
            hashes.insert(sha256Hex(data))
        }
        return hashes
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
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
    @State private var editorSelection: EntryEditorSelection?

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

                        Button("Edit") {
                            editorSelection = EntryEditorSelection(id: entry.id)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button("Edit") {
                            editorSelection = EntryEditorSelection(id: entry.id)
                        }

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
        .sheet(item: $editorSelection) { selection in
            MacEntryEditorPane(entryID: selection.id)
        }
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
