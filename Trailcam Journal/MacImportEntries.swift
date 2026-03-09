
//
//  MacImportEntries.swift
//  Trailcam Journal
//

import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

#if os(macOS)

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Import pane (drafts)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct MacImportPane: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore

    @State private var isImporting       = false
    @State private var lastImportCount:  Int?
    @State private var lastError:        String?
    @State private var selectedDraftID:  UUID?

    // Batch-selection mode
    @State private var isSelecting       = false
    @State private var selectedIDs:      Set<UUID> = []
    @State private var confirmBatchDelete = false

    private var drafts: [TrailEntry] {
        store.entries.filter { $0.isDraft }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if drafts.isEmpty {
                    importEmptyState
                } else {
                    draftList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
            .navigationTitle("Import Queue")
            .toolbar { importToolbar }
        }
        .sheet(isPresented: Binding(
            get: { selectedDraftID != nil },
            set: { if !$0 { selectedDraftID = nil } }
        )) {
            if let id = selectedDraftID {
                MacDraftEditView(entryID: id)
                    .environmentObject(store)
                    .environmentObject(savedLocationStore)
            }
        }
        .alert("Delete \(selectedIDs.count) draft\(selectedIDs.count == 1 ? "" : "s")?",
               isPresented: $confirmBatchDelete) {
            Button("Delete", role: .destructive) { executeBatchDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the selected drafts and their photos.")
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var importToolbar: some ToolbarContent {

        // Left / cancel action
        if isSelecting {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    isSelecting = false
                    selectedIDs = []
                }
            }
        }

        // Status centre
        ToolbarItem(placement: .status) {
            Group {
                if isImporting {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Importing…")
                            .foregroundStyle(.secondary).font(.subheadline)
                    }
                } else if isSelecting {
                    Text(selectedIDs.isEmpty
                         ? "Select drafts"
                         : "\(selectedIDs.count) selected")
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        .font(.subheadline)
                } else if !drafts.isEmpty {
                    Text("\(drafts.count) draft\(drafts.count == 1 ? "" : "s") waiting")
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        .font(.subheadline)
                }
            }
        }

        // Batch actions (visible while selecting)
        if isSelecting {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    confirmBatchDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedIDs.isEmpty)
                .help("Delete selected drafts")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { executeBatchFinalise() } label: {
                    Label("Finalise", systemImage: "checkmark.circle")
                }
                .disabled(selectedIDs.isEmpty || !anyReadySelected)
                .help(anyReadySelected
                      ? "Finalise selected ready drafts"
                      : "Selected drafts are missing species or location")
            }
        } else {
            // Normal mode: Select + Import
            if !drafts.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isSelecting = true
                        selectedIDs = []
                    } label: {
                        Label("Select", systemImage: "checkmark.circle")
                    }
                    .help("Select drafts to batch-finalise or delete")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { importFromOpenPanel() } label: {
                    Label("Import Photos…", systemImage: "square.and.arrow.down")
                }
                .disabled(isImporting)
                .help("Choose photos to import from Finder")
            }
        }
    }

    // MARK: Empty state

    private var importEmptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "photo.stack")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(AppColors.primary.opacity(0.3))

            VStack(spacing: 6) {
                Text("No drafts yet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.primary)
                Text("Click Import Photos to bring in images from your Mac.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            Button { importFromOpenPanel() } label: {
                Label("Import Photos…", systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isImporting)
        }
        .padding(48)
    }

    // MARK: Draft list

    private var draftList: some View {
        VStack(spacing: 0) {
            if let count = lastImportCount {
                inlineBanner("Imported \(count) photo\(count == 1 ? "" : "s").", color: AppColors.secondary)
            } else if let err = lastError {
                inlineBanner(err, color: .red)
            }

            List(drafts) { entry in
                Button {
                    if isSelecting {
                        toggleSelection(entry.id)
                    } else {
                        selectedDraftID = entry.id
                    }
                } label: {
                    HStack(spacing: 0) {
                        if isSelecting {
                            Image(systemName: selectedIDs.contains(entry.id)
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedIDs.contains(entry.id)
                                                 ? AppColors.primary : .secondary)
                                .padding(.trailing, 10)
                        }
                        MacDraftRow(entry: entry)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    selectedIDs.contains(entry.id)
                        ? AppColors.primary.opacity(0.06)
                        : Color.white
                )
                .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
        }
    }

    private func inlineBanner(_ message: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: color == .red
                  ? "exclamationmark.circle.fill"
                  : "checkmark.circle.fill")
                .foregroundStyle(color)
            Text(message).font(.subheadline).foregroundStyle(color)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(color.opacity(0.07))
    }

    // MARK: Batch helpers

    private var anyReadySelected: Bool {
        drafts.filter { selectedIDs.contains($0.id) }
            .contains { MacDraftStatus(entry: $0) == .ready }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else                        { selectedIDs.insert(id) }
    }

    private func executeBatchFinalise() {
        for i in store.entries.indices {
            guard selectedIDs.contains(store.entries[i].id),
                  MacDraftStatus(entry: store.entries[i]) == .ready else { continue }
            store.entries[i].isDraft = false
        }
        isSelecting = false
        selectedIDs = []
    }

    private func executeBatchDelete() {
        for id in selectedIDs { store.deleteEntry(id: id) }
        isSelecting = false
        selectedIDs = []
    }

    // MARK: Import logic

    private func importFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.jpeg, .png, .tiff, .heic, .heif, .image]
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        isImporting = true; lastImportCount = nil; lastError = nil
        var imported = 0
        for url in panel.urls {
            guard let data     = try? Data(contentsOf: url) else { continue }
            let  meta          = extractMetadata(from: data)
            guard let filename = MacImageStore.saveDownsampledJPEG(data: data) else { continue }
            store.entries.insert(
                TrailEntry(
                    id: UUID(), date: meta.date ?? Date(),
                    species: nil, camera: nil, notes: "", tags: [],
                    photoFilename: filename,
                    latitude: meta.latitude, longitude: meta.longitude,
                    locationUnknown: false, isDraft: true,
                    originalFilename: url.lastPathComponent, photoAssetId: nil
                ),
                at: 0
            )
            imported += 1
        }
        isImporting = false
        if imported > 0 { lastImportCount = imported }
        else { lastError = "No images imported — check file format or permissions." }
    }

    private func extractMetadata(
        from data: Data
    ) -> (date: Date?, latitude: Double?, longitude: Double?) {
        guard let src   = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        else { return (nil, nil, nil) }

        var date: Date?
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let raw  = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            date = Self.exifDF.date(from: raw)
        }
        if date == nil,
           let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let raw  = tiff[kCGImagePropertyTIFFDateTime] as? String {
            date = Self.exifDF.date(from: raw)
        }

        var lat: Double?, lon: Double?
        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            lat = gps[kCGImagePropertyGPSLatitude]  as? Double
            lon = gps[kCGImagePropertyGPSLongitude] as? Double
            if let r = gps[kCGImagePropertyGPSLatitudeRef]  as? String, r.uppercased() == "S", let v = lat  { lat = -abs(v) }
            if let r = gps[kCGImagePropertyGPSLongitudeRef] as? String, r.uppercased() == "W", let v = lon { lon = -abs(v) }
        }
        return (date, lat, lon)
    }

    private static let exifDF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"; return f
    }()
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Entries pane (finalised)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct MacEntriesPane: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore

    @State private var searchText      = ""
    @State private var selectedTag:    String?
    @State private var pendingDelete:  TrailEntry?
    @State private var showDeleteAlert = false
    @State private var selectedEntryID: UUID?

    // Filters
    @State private var showFilterPopover = false
    @State private var filterCamera:    String = ""   // "" = all cameras
    @State private var filterDateFrom:  Date   = Calendar.current.date(
        byAdding: .year, value: -10, to: Date()) ?? Date()
    @State private var filterDateTo:    Date   = Date()
    @State private var dateFilterActive = false

    private var finalizedEntries: [TrailEntry] {
        store.entries.filter { !$0.isDraft }.sorted { $0.date > $1.date }
    }

    private var allTags: [String] {
        Array(
            finalizedEntries.flatMap { $0.tags }
                .reduce(into: Set<String>()) { $0.insert($1) }
        ).sorted()
    }

    private var allCameras: [String] {
        Array(
            finalizedEntries.compactMap { $0.camera }.filter { !$0.isEmpty }
                .reduce(into: Set<String>()) { $0.insert($1) }
        ).sorted()
    }

    private var filteredEntries: [TrailEntry] {
        var result = finalizedEntries

        // Tag filter
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }
        // Camera filter
        if !filterCamera.isEmpty {
            result = result.filter { $0.camera == filterCamera }
        }
        // Date range filter
        if dateFilterActive {
            let from = Calendar.current.startOfDay(for: filterDateFrom)
            let to   = Calendar.current.date(byAdding: .day, value: 1,
                                              to: Calendar.current.startOfDay(for: filterDateTo)) ?? filterDateTo
            result = result.filter { $0.date >= from && $0.date < to }
        }
        // Text search
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { e in
                [(e.species ?? ""), (e.camera ?? ""), e.notes,
                 EntryFormatting.locationLabel(for: e, savedLocations: savedLocationStore.locations),
                 e.tags.joined(separator: " ")]
                    .map { $0.lowercased() }
                    .contains { $0.contains(q) }
            }
        }
        return result
    }

    private var isFiltered: Bool {
        !filterCamera.isEmpty || dateFilterActive
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !allTags.isEmpty { tagChipBar; Divider() }
                if filteredEntries.isEmpty { entriesEmptyState } else { entryList }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
            .navigationTitle("Entries")
            .searchable(text: $searchText, placement: .toolbar,
                        prompt: "Species, location, notes, tags…")
            .toolbar { entriesToolbar }
        }
        .alert("Delete entry?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let id = pendingDelete?.id { store.deleteEntry(id: id) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { Text("This will permanently remove this entry and its photo.") }
        .sheet(isPresented: Binding(
            get: { selectedEntryID != nil },
            set: { if !$0 { selectedEntryID = nil } }
        )) {
            if let id = selectedEntryID {
                MacEntryDetailView(entryID: id)
                    .environmentObject(store)
                    .environmentObject(savedLocationStore)
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var entriesToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showFilterPopover.toggle()
            } label: {
                Label("Filter",
                      systemImage: isFiltered
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
                    .foregroundStyle(isFiltered ? AppColors.primary : .primary)
            }
            .help("Filter entries")
            .popover(isPresented: $showFilterPopover, arrowEdge: .bottom) {
                filterPopover
            }
        }
    }

    // MARK: Filter popover

    private var filterPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Filter Entries")
                .font(.headline)
                .foregroundStyle(AppColors.primary)
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

            Divider()

            Form {
                Section("Camera") {
                    Picker("Camera", selection: $filterCamera) {
                        Text("All cameras").tag("")
                        ForEach(allCameras, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }

                Section("Date range") {
                    Toggle("Filter by date", isOn: $dateFilterActive)
                    if dateFilterActive {
                        DatePicker("From", selection: $filterDateFrom,
                                   displayedComponents: .date)
                        DatePicker("To",   selection: $filterDateTo,
                                   displayedComponents: .date)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Divider()

            HStack {
                Button("Clear All") {
                    filterCamera    = ""
                    dateFilterActive = false
                }
                .disabled(!isFiltered)
                Spacer()
                Button("Done") { showFilterPopover = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding(14)
        }
        .frame(width: 300)
        .background(AppColors.background)
    }

    // MARK: Tag chip bar

    private var tagChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(allTags, id: \.self) { tag in
                    Button {
                        selectedTag = (selectedTag == tag) ? nil : tag
                    } label: {
                        Text("#\(tag)")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(
                                selectedTag == tag
                                    ? AppColors.primary
                                    : AppColors.primary.opacity(0.09)
                            )
                            .foregroundStyle(
                                selectedTag == tag ? Color.white : AppColors.primary
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Empty state

    private var entriesEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(AppColors.primary.opacity(0.28))
            Text(searchText.isEmpty && selectedTag == nil && !isFiltered
                 ? "No entries yet"
                 : "No matching entries")
                .font(.title3.weight(.semibold)).foregroundStyle(AppColors.primary)
            Text(searchText.isEmpty && selectedTag == nil && !isFiltered
                 ? "Finalise drafts in the Import Queue to see them here."
                 : "Try adjusting your search terms or filters.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 320)
            if isFiltered || selectedTag != nil {
                Button("Clear Filters") {
                    filterCamera    = ""
                    dateFilterActive = false
                    selectedTag     = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Entry list

    private var entryList: some View {
        List(filteredEntries) { entry in
            Button { selectedEntryID = entry.id } label: {
                MacEntryRow(
                    entry: entry,
                    locationText: EntryFormatting.locationLabel(
                        for: entry, savedLocations: savedLocationStore.locations)
                )
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.white)
            .listRowSeparator(.hidden)
            .contextMenu {
                Button(role: .destructive) {
                    pendingDelete = entry; showDeleteAlert = true
                } label: {
                    Label("Delete Entry", systemImage: "trash")
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Row views
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Draft row — filename, date, and coloured status pill.
private struct MacDraftRow: View {
    let entry: TrailEntry
    private var status: MacDraftStatus { MacDraftStatus(entry: entry) }

    var body: some View {
        HStack(spacing: 14) {
            MacThumbnail(entry: entry)
                .frame(width: 92, height: 68)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.originalFilename ?? "Untitled image")
                        .font(.headline)
                        .foregroundStyle(AppColors.primary)
                        .lineLimit(1)
                    Spacer()
                    Text("DRAFT")
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.82))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                HStack(spacing: 5) {
                    Circle().fill(status.color).frame(width: 7, height: 7)
                    Text(status.label).font(.caption).foregroundStyle(status.color)
                }
            }
        }
        .padding(.vertical, 9).padding(.horizontal, 6)
        .contentShape(Rectangle())
    }
}

/// Finalized entry row — species + camera + location on the left, date on the right.
private struct MacEntryRow: View {
    let entry: TrailEntry
    let locationText: String

    var body: some View {
        HStack(spacing: 14) {
            MacThumbnail(entry: entry)
                .frame(width: 92, height: 68)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.species ?? "Unknown species")
                    .font(.headline)
                    .foregroundStyle(AppColors.primary)
                    .lineLimit(1)

                if let cam = entry.camera, !cam.isEmpty {
                    Label(cam, systemImage: "camera")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                if !locationText.isEmpty {
                    Label(locationText, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                if !entry.tags.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(entry.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(AppColors.secondary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(AppColors.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        if entry.tags.count > 3 {
                            Text("+\(entry.tags.count - 3)")
                                .font(.caption2).foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
            }

            Spacer(minLength: 12)

            // Right: date stack
            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.date.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.subheadline).foregroundStyle(AppColors.textSecondary)
                Text(entry.date.formatted(.dateTime.hour().minute()))
                    .font(.caption).foregroundStyle(AppColors.textSecondary.opacity(0.65))
            }
        }
        .padding(.vertical, 9).padding(.horizontal, 6)
        .contentShape(Rectangle())
    }
}

#endif
