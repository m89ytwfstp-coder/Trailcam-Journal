//
//  SettingsView.swift
//  Trailcam Journal
//

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore

    @AppStorage("settings.showDraftsInEntries") private var showDraftsInEntries: Bool = true
    @AppStorage("settings.autoRecenterMap") private var autoRecenterMap: Bool = true
    @AppStorage("settings.clusterListMax") private var clusterListMax: Int = 12

    @State private var confirmDeleteDrafts = false
    @State private var confirmDeleteAllEntries = false
    @State private var confirmClearThumbCache = false
    @State private var confirmClearLocations = false
    @State private var confirmClearSpeciesPhotos = false

    // Section 11: live storage stats
    @State private var storageStats: StorageStats? = nil

    // Section 12e: re-compress progress (Mac only)
    @State private var isRecompressing      = false
    @State private var recompressProgress: String? = nil

    // Export state
    @State private var exportMessage: String? = nil

    private struct StorageStats {
        let photoCount: Int
        let photosMB: Double
        let thumbCacheMB: Double
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    AppHeader(title: "Settings", subtitle: "Preferences and data tools")

                    card(title: "App") {
                        Toggle("Show drafts in Entries", isOn: $showDraftsInEntries)
                        Toggle("Auto recenter map on changes", isOn: $autoRecenterMap)
                    }

                    card(title: "Map") {
                        Stepper(value: $clusterListMax, in: 3...30, step: 1) {
                            HStack {
                                Text("Cluster list max")
                                Spacer()
                                Text("\(clusterListMax)")
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }

                        Text("If a cluster has ≤ this number of entries, tapping it shows the list. Otherwise it zooms in.")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    card(title: "Maintenance") {
                        maintenanceButton(
                            title: "Delete all drafts",
                            systemImage: "trash",
                            role: .destructive
                        ) {
                            confirmDeleteDrafts = true
                        }

                        maintenanceButton(
                            title: "Delete all entries",
                            systemImage: "trash.fill",
                            role: .destructive
                        ) {
                            confirmDeleteAllEntries = true
                        }

                        maintenanceButton(
                            title: "Remove all saved locations",
                            systemImage: "mappin.slash",
                            role: .destructive
                        ) {
                            confirmClearLocations = true
                        }
                    }

                    // F5: Data export card
                    card(title: "Export Data") {
                        Text("Export all finalized entries as a spreadsheet or structured data file.")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)

                        HStack(spacing: 12) {
                            Button {
                                exportEntries(format: .csv)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "tablecells")
                                    Text("Export CSV")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(AppColors.primary)

                            Button {
                                exportEntries(format: .json)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "curlybraces")
                                    Text("Export JSON")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(AppColors.primary)
                        }

                        if let msg = exportMessage {
                            Text(msg)
                                .font(.footnote)
                                .foregroundStyle(AppColors.textSecondary)
                                .transition(.opacity)
                        }
                    }

                    // Section 11: Storage card
                    card(title: "Storage") {
                        let finalizedCount = store.entries.filter { !$0.isDraft }.count
                        let draftCount     = store.entries.filter {  $0.isDraft }.count

                        statRow("Entries", value: "\(store.entries.count)  (\(finalizedCount) final / \(draftCount) draft)")
                        statRow("Saved locations", value: "\(savedLocationStore.pins.count)")

                        if let stats = storageStats {
                            statRow("Photos on disk", value: "\(stats.photoCount) files  (\(String(format: "%.1f", stats.photosMB)) MB)")
                            statRow("Thumbnail cache", value: "\(String(format: "%.1f", stats.thumbCacheMB)) MB")
                        } else {
                            HStack {
                                Text("Calculating…")
                                    .foregroundStyle(AppColors.textSecondary)
                                    .font(.subheadline)
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }

                        Divider().padding(.vertical, 4)

                        maintenanceButton(
                            title: "Clear thumbnail cache",
                            systemImage: "sparkles",
                            role: .destructive
                        ) {
                            confirmClearThumbCache = true
                        }

                        maintenanceButton(
                            title: "Clear species photos",
                            systemImage: "photo.on.rectangle.angled",
                            role: .destructive
                        ) {
                            confirmClearSpeciesPhotos = true
                        }

#if os(macOS)
                        // Section 12e: re-compress legacy full-size photos
                        Button {
                            recompressLegacyPhotos()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 24, alignment: .center)
                                Text("Re-compress photos")
                                    .font(.body)
                                Spacer()
                                if isRecompressing {
                                    ProgressView().scaleEffect(0.8)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .disabled(isRecompressing)
                        .tint(AppColors.primary)

                        if let progress = recompressProgress {
                            Text(progress)
                                .font(.footnote)
                                .foregroundStyle(AppColors.textSecondary)
                        }
#endif
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .appScreenBackground()
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear { loadStorageStats() }
        }
        .alert("Delete all drafts?", isPresented: $confirmDeleteDrafts) {
            Button("Delete drafts", role: .destructive) {
                store.deleteAllDrafts()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all draft entries. Saved entries are unchanged.")
        }
        .alert("Delete ALL entries?", isPresented: $confirmDeleteAllEntries) {
            Button("Delete everything", role: .destructive) {
                store.deleteAllEntries()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all entries (finalized + drafts). This cannot be undone.")
        }
        .alert("Clear thumbnail cache?", isPresented: $confirmClearThumbCache) {
            Button("Clear cache", role: .destructive) {
#if os(iOS)
                ImageStorage.clearThumbnailCache()
#endif
                loadStorageStats()   // refresh numbers immediately after clearing
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only removes cached thumbnails. Entries remain.")
        }
        .alert("Clear species photos?", isPresented: $confirmClearSpeciesPhotos) {
            Button("Clear photos", role: .destructive) {
                clearSpeciesPhotoCache()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All downloaded species photos will be deleted. They'll be re-fetched next time the Bucket List is opened.")
        }
        .alert("Remove all saved locations?", isPresented: $confirmClearLocations) {
            Button("Remove locations", role: .destructive) {
                savedLocationStore.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all pinned locations. Entries are unchanged.")
        }
    }

    // MARK: - Export helpers (F5)

    private enum ExportFormat { case csv, json }

    private func exportEntries(format: ExportFormat) {
        let finalized = store.entries.filter { !$0.isDraft }

        switch format {
        case .csv:
            let data = buildCSV(entries: finalized)
            saveFile(data: data, defaultName: "trailcam-entries.csv", contentType: "text/csv")
        case .json:
            guard let data = buildJSON(entries: finalized) else { return }
            saveFile(data: data, defaultName: "trailcam-entries.json", contentType: "application/json")
        }
    }

    private func buildCSV(entries: [TrailEntry]) -> Data {
        var rows: [String] = []
        let header = "id,date,type,species,camera,notes,tags,latitude,longitude,trip_id"
        rows.append(header)

        let df = ISO8601DateFormatter()
        for e in entries {
            func escape(_ s: String?) -> String {
                guard let s else { return "" }
                if s.contains(",") || s.contains("\"") || s.contains("\n") {
                    return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                }
                return s
            }
            let cols: [String] = [
                e.id.uuidString,
                df.string(from: e.date),
                e.entryType.rawValue,
                escape(e.species),
                escape(e.camera),
                escape(e.notes),
                escape(e.tags.joined(separator: ";")),
                e.latitude.map  { String($0) } ?? "",
                e.longitude.map { String($0) } ?? "",
                e.tripID?.uuidString ?? ""
            ]
            rows.append(cols.joined(separator: ","))
        }
        return rows.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    private func buildJSON(entries: [TrailEntry]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting  = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(entries)
    }

    private func saveFile(data: Data, defaultName: String, contentType: String) {
#if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes  = [.init(mimeType: contentType) ?? .item]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
            exportMessage = "Saved \(url.lastPathComponent) (\(data.count / 1024) KB)"
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
#else
        // iOS: write to temp dir then share
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(defaultName)
        guard (try? data.write(to: tmpURL)) != nil else {
            exportMessage = "Export failed."
            return
        }
        exportMessage = "File ready in temporary storage."
#endif
    }

    // MARK: - Storage stats helpers (Section 11)

    private func loadStorageStats() {
        Task.detached(priority: .utility) {
            let docs  = FileManager.default.urls(for: .documentDirectory,  in: .userDomainMask).first
            let cache = FileManager.default.urls(for: .cachesDirectory,    in: .userDomainMask).first?
                .appendingPathComponent("TrailcamThumbs")

            let photoBytes = directorySize(docs)
            let cacheBytes = directorySize(cache)
            let photoCount = (try? FileManager.default.contentsOfDirectory(atPath: docs?.path ?? ""))?
                .filter { $0.hasSuffix(".jpg") }.count ?? 0

            await MainActor.run {
                storageStats = StorageStats(
                    photoCount: photoCount,
                    photosMB:   Double(photoBytes) / 1_048_576,
                    thumbCacheMB: Double(cacheBytes) / 1_048_576
                )
            }
        }
    }

    private func directorySize(_ url: URL?) -> Int {
        guard let url else { return 0 }
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        return (enumerator?.compactMap {
            ($0 as? URL).flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
        }.reduce(0, +)) ?? 0
    }

    // MARK: - Re-compress legacy photos (Section 12e, Mac only)

#if os(macOS)
    private func recompressLegacyPhotos() {
        isRecompressing     = true
        recompressProgress  = "Starting…"

        // Capture work list on MainActor before entering background task.
        let toProcess: [(id: UUID, filename: String)] = store.entries.compactMap { entry in
            guard entry.photoThumbnailFilename == nil,
                  let filename = entry.photoFilename else { return nil }
            return (entry.id, filename)
        }
        let total = toProcess.count

        Task.detached(priority: .utility) {
            var done = 0
            for item in toProcess {
                guard let oldURL = MacImageStore.fileURL(for: item.filename),
                      let data   = try? Data(contentsOf: oldURL),
                      let pair   = MacImageStore.saveImagePair(data: data)
                else { continue }

                // Only remove the old file once both new files are safely written.
                try? FileManager.default.removeItem(at: oldURL)
                MacThumbnailCache.shared.removeAll()   // invalidate stale cached images

                let newDisplay = pair.displayFilename
                let newThumb   = pair.thumbnailFilename
                let entryID    = item.id
                done += 1
                let d = done

                await MainActor.run {
                    if let idx = store.entries.firstIndex(where: { $0.id == entryID }) {
                        store.entries[idx].photoFilename          = newDisplay
                        store.entries[idx].photoThumbnailFilename = newThumb
                    }
                    recompressProgress = "Processed \(d) of \(total)…"
                }
            }

            await MainActor.run {
                isRecompressing    = false
                recompressProgress = total > 0
                    ? "Done — \(total) photo\(total == 1 ? "" : "s") re-compressed."
                    : "Nothing to re-compress."
                loadStorageStats()
            }
        }
    }
#endif

    // MARK: - UI helpers

    @ViewBuilder
    private func card(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.surface.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // Keep Int overload for existing callsites
    private func statRow(_ label: String, value: Int) -> some View {
        statRow(label, value: "\(value)")
    }

    // MARK: - Species photo cache helper

    private func clearSpeciesPhotoCache() {
        let dir = SpeciesPhotoService.photosDirectory
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        )) ?? []
        files.forEach { try? FileManager.default.removeItem(at: $0) }

        // Also wipe the URL cache so fetches are retried
        SpeciesPhotoCache.shared.clearAll()
    }

    private func maintenanceButton(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 24, alignment: .center)

                Text(title)
                    .font(.body)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .tint(.red)
    }

}
